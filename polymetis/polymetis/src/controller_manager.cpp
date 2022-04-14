// Copyright (c) Facebook, Inc. and its affiliates.

// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#include "controller_manager.hpp"

void ControllerManager::initRobotClient(const RobotClientMetadata *metadata,
                                        std::string &error_msg) {
  spdlog::info("==== Initializing new RobotClient... ====");

  num_dofs_ = metadata->dof();

  torch_robot_state_ =
      std::unique_ptr<TorchRobotState>(new TorchRobotState(num_dofs_));

  // Load default controller bytes into model buffer
  std::vector<char> model_buffer;
  std::string binary_blob = metadata->default_controller();
  for (int i = 0; i < binary_blob.size(); i++) {
    model_buffer.push_back(binary_blob[i]);
  }

  // Load default controller from model buffer
  try {
    robot_client_context_.default_controller =
        new TorchScriptedController(model_buffer.data(), model_buffer.size());
  } catch (const std::exception &e) {
    error_msg = "Failed to load default controller: " + std::string(e.what());
    spdlog::error(error_msg);
    return;
  }

  // Set URDF file of new context
  robot_client_context_.metadata = RobotClientMetadata(*metadata);

  // Set last updated timestep of robot client context
  robot_client_context_.last_update_ns = getNanoseconds();

  resetControllerContext();

  spdlog::info("Success.");
}

RobotClientMetadata
ControllerManager::getRobotClientMetadata(RobotClientMetadata *metadata,
                                          std::string &error_msg) {
  if (!validRobotContext()) {
    error_msg = "Robot context not valid when calling GetRobotClientMetadata!";
  }
  *metadata = robot_client_context_.metadata;
}

// Log querying methods

RobotState *getStateByBufferIndex(int index) {
  return robot_state_buffer_.get(i);
}

int ControllerManager::getStateBufferSize(void) {
  return robot_state_buffer_.size()
}

void ControllerManager::getEpisodeInterval(LogInterval *interval) {
  interval->set_start(-1);
  interval->set_end(-1);

  if (custom_controller_context_.status != UNINITIALIZED) {
    interval->set_start(custom_controller_context_.episode_begin);
    interval->set_end(custom_controller_context_.episode_end);
  }

  return Status::OK;
}

// Interface methods

void ControllerManager::controlUpdate(const RobotState *robot_state,
                                      std::vector<float> &desired_torque,
                                      std::string &error_msg) {
  // Check if last update is stale
  if (!validRobotContext()) {
    spdlog::warn("Interrupted control update greater than threshold of {} ns. "
                 "Reverting to default controller...",
                 threshold_ns_);
    custom_controller_context_.status = TERMINATING;
  }

  // Parse robot state
  torch_robot_state_->update_state(
      robot_state->timestamp().seconds(), robot_state->timestamp().nanos(),
      std::vector<float>(robot_state->joint_positions().begin(),
                         robot_state->joint_positions().end()),
      std::vector<float>(robot_state->joint_velocities().begin(),
                         robot_state->joint_velocities().end()),
      std::vector<float>(robot_state->motor_torques_measured().begin(),
                         robot_state->motor_torques_measured().end()),
      std::vector<float>(robot_state->motor_torques_external().begin(),
                         robot_state->motor_torques_external().end()));

  // Lock to prevent 1) controller updates while controller is running; 2)
  // external termination during controller selection, which might cause loading
  // of a uninitialized default controller
  custom_controller_context_.controller_mtx.lock();

  // Update episode markers
  if (custom_controller_context_.status == READY) {
    // First step of episode: update episode marker
    custom_controller_context_.episode_begin = robot_state_buffer_.size();
    custom_controller_context_.status = RUNNING;

  } else if (custom_controller_context_.status == TERMINATING) {
    // Last step of episode: update episode marker & reset default controller
    custom_controller_context_.episode_end = robot_state_buffer_.size() - 1;
    custom_controller_context_.status = TERMINATED;

    robot_client_context_.default_controller->reset();

    spdlog::info(
        "Terminating custom controller, switching to default controller.");
  }

  // Select controller
  TorchScriptedController *controller;
  if (custom_controller_context_.status == RUNNING) {
    controller = custom_controller_context_.custom_controller;
  } else {
    controller = robot_client_context_.default_controller;
  }
  try {
    desired_torque = controller->forward(*torch_robot_state_);
  } catch (const std::exception &e) {
    custom_controller_context_.controller_mtx.unlock();
    error_msg =
        "Failed to run controller forward function: " + std::string(e.what());
    spdlog::error(error_msg);
    return;
  }

  // Unlock
  custom_controller_context_.controller_mtx.unlock();
  for (int i = 0; i < num_dofs_; i++) {
    torque_command->add_joint_torques(desired_torque[i]);
  }
  setTimestampToNow(torque_command->mutable_timestamp());

  // Record robot state
  RobotState robot_state_copy(*robot_state);
  for (int i = 0; i < num_dofs_; i++) {
    robot_state_copy.add_joint_torques_computed(
        torque_command->joint_torques(i));
  }
  robot_state_buffer_.append(robot_state_copy);

  // Update timestep & check termination
  if (custom_controller_context_.status == RUNNING) {
    custom_controller_context_.timestep++;
    if (controller->is_terminated()) {
      custom_controller_context_.status = TERMINATING;
    }
  }

  robot_client_context_.last_update_ns = getNanoseconds();
}

void ControllerManger::setController(std::vector<char> &model_buffer,
                                     LogInterval *interval,
                                     std::string &error_msg) {
  interval->set_start(-1);
  interval->set_end(-1);

  try {
    // Load new controller
    auto new_controller = std::make_shared<TorchScriptedController>(
        model_buffer.data(), model_buffer.size());

    // Switch in new controller by updating controller context
    custom_controller_context_.controller_mtx.lock();

    controller_status_ = UNINITIALIZED current_custom_controller_ =
        new_controller;
    custom_controller_context_.status = READY;

    custom_controller_context_.controller_mtx.unlock();
    spdlog::info("Loaded new controller.");

  } catch (const std::exception &e) {
    error_msg = "Failed to load new controller: " + std::string(e.what());
    spdlog::error(error_msg);
    return;
  }

  // Respond with start index
  while (custom_controller_context_.status == READY) {
    usleep(SPIN_INTERVAL_USEC);
  }
  interval->set_start(custom_controller_context_.episode_begin);
}

void updateController(std::vector<char> &update_buffer, LogInterval *interval,
                      std::string &error_msg) {
  interval->set_start(-1);
  interval->set_end(-1);

  // Load param container
  if (!current_custom_controller_->param_dict_load(update_buffer.data(),
                                                   update_buffer.size())) {
    error_msg = "Failed to load new controller params.";
    spdlog::error(error_msg);
    return;
  }

  // Update controller & set intervals
  if (controller_status_ == RUNNING) {
    try {
      custom_controller_context_.controller_mtx.lock();
      interval->set_start(robot_state_buffer_.size());
      current_custom_controller_->param_dict_update_module();
      custom_controller_context_.controller_mtx.unlock();

    } catch (const std::exception &e) {
      custom_controller_context_.controller_mtx.unlock();

      error_msg = "Failed to update controller: " + std::string(e.what());
      spdlog::error(error_msg);
      return;
    }

  } else {
    error_msg =
        "Tried to perform a controller update with no controller running.";
    spdlog::warn(error_msg);
    return;
  }
}

void ControllerManger::terminateController(LogInterval *interval,
                                           std::string &error_msg) {
  interval->set_start(-1);
  interval->set_end(-1);

  if (controller_status_ == RUNNING) {
    custom_controller_context_.controller_mtx.lock();
    controller_status_ = TERMINATING;
    custom_controller_context_.controller_mtx.unlock();

    // Respond with start & end index
    while (controller_status_ == TERMINATING) {
      usleep(SPIN_INTERVAL_USEC);
    }
    interval->set_start(custom_controller_context_.episode_begin);
    interval->set_end(custom_controller_context_.episode_end);

  } else {
    error_msg = "Tried to terminate controller with no controller running.";
    spdlog::warn(error_msg);
    return;
  }
}

// Helper methods

void ControllerManager::resetControllerContext(void) {
  custom_controller_context_.episode_begin = -1;
  custom_controller_context_.episode_end = -1;
  custom_controller_context_.timestep = 0;
  custom_controller_context_.status = UNINITIALIZED;
}

bool ControllerManager::validRobotContext(void) {
  if (robot_client_context_.last_update_ns == 0) {
    return false;
  }
  long int time_since_last_update =
      getNanoseconds() - robot_client_context_.last_update_ns;
  return time_since_last_update < threshold_ns_;
}