# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
import time
import torch
from polymetis import RobotInterface
import torchcontrol as toco
from typing import Dict
import numpy as np 

# Policy class taken from examples/4_custom_updatable_controller.py
class MyPDPolicy(toco.PolicyModule):
    """
    Custom policy that performs PD control around a desired joint position
    """

    def __init__(self, joint_pos_current, kq, kqd, **kwargs):
        """
        Args:
            joint_pos_current (torch.Tensor):   Joint positions at initialization
            kq, kqd (torch.Tensor):             PD gains (1d array)
        """
        super().__init__(**kwargs)

        self.q_desired = torch.nn.Parameter(joint_pos_current)

        # Initialize modules
        self.feedback = toco.modules.JointSpacePD(kq, kqd)

    def forward(self, state_dict: Dict[str, torch.Tensor]):
        # Parse states
        q_current = state_dict["joint_positions"]
        qd_current = state_dict["joint_velocities"]

        # Execute PD control
        output = self.feedback(
            q_current, qd_current, self.q_desired, torch.zeros_like(qd_current)
        )

        return {"joint_torques": output}


def go_to_goal(robot, start, goal, time_to_go = 5.0, hz = 50):
    total = int(time_to_go * hz)
    for t in range(total):
        interp_state = ((total-t)/(total-1)) * start + ((t-1)/(total-1)) * goal
        robot.update_current_policy({"q_desired": interp_state})
        time.sleep(1 / hz)

if __name__ == "__main__":
    # Initialize robot interface
    robot = RobotInterface(
        ip_address="172.16.0.1", enforce_version = False, 
    )

    # Reset
    robot.go_home()

    # Create policy instance
    q_initial = robot.get_joint_positions()
    default_kq = torch.Tensor(robot.metadata.default_Kq)
    default_kqd = torch.Tensor(robot.metadata.default_Kqd)
    policy = MyPDPolicy(
        joint_pos_current=q_initial,
        kq = default_kq,
        kqd = default_kqd,
    )

    # Send policy
    print("\nRunning PD policy...")

    # Update policy to execute a sine trajectory on joint 6 for 5 seconds
    print("Sine motion for all all Allegro joints")

    time_to_go = 2.0
    m = 0.5  # magnitude of sine wave (rad)
    T = 2.0  # period of sine wave
    hz = 50  # update frequency

    joints = ["index 1", "index 2", "index 3", "index 4", 
              "middle 1", "middle 2", "middle 3", "middle 4",
              "ring 1", "ring 2", "ring 3", "ring 4", 
              "thumb 1", "thumb 2", "thumb 3", "thumb 4"]

    robot.send_torch_policy(policy, blocking=False)

    for j_id, joint_name in enumerate(joints):
        max_angle = 15
        q_desired = q_initial.clone()
        q_desired[j_id] = q_initial[j_id] + np.deg2rad(max_angle)
        print(f"Joint: {joint_name}")
        go_to_goal(robot = robot, start = q_initial, goal = q_desired, time_to_go = time_to_go, hz = hz)
        # for i in range(int(time_to_go * hz)):
        #     print(np.rad2deg(m * np.sin(np.pi * i / (T * hz))))
        #     q_desired[j_id] = q_initial[j_id] + m * np.sin(np.pi * i / (T * hz))
        go_to_goal(robot = robot, start = q_desired, goal = q_initial, time_to_go = time_to_go, hz = hz)

    state_log = robot.terminate_current_policy()

    print("Terminating PD policy...")
    state_log = robot.terminate_current_policy()
    # Go home


    # R = 10
    # j_p = 0.1 * torch.linspace(-R/2, R/2, steps=R)
    # joints = ["index 1", "index 2", "index 3", "index 4", 
    #           "middle 1", "middle 2", "middle 3", "middle 4",
    #           "ring 1", "ring 2", "ring 3", "ring 4", 
    #           "thumb 1", "thumb 2", "thumb 3", "thumb 4"]
    # for i, f in enumerate(joints):
    #     print(f"Joint: {f}")
    #     joint_pos = robot.get_joint_positions()
    #     for j in tqdm(range(R)):
    #         joint_pos_new = copy.deepcopy(joint_pos)
    #         joint_pos_new[i] = j_p[j]
    #         # print(f"Move to join positions: {joint_pos}")
    #         # Move to joint positions
    #         # robot.move_to_joint_positions(joint_pos_new, time_to_go = 5)
    #         robot.update_current_policy({"q_desired": joint_pos_new})
    #         print(f"EE pose: {robot.get_ee_pose()}")
    #         time.sleep(.1)
    #     robot.go_home()



    # while True: 
    #     joint_pos = robot.get_joint_positions()
    #     print(f"Joint pos: {joint_pos}")
    #     time.sleep(1)

