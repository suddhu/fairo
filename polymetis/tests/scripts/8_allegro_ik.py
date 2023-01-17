import os
import cv2
import numpy as np
import yaml

from utils.ik_teleop.ik_core.allegro_controller import AllegroIKController
from utils.ik_teleop.utils.transformations import perform_persperctive_transformation
from copy import deepcopy as copy

URDF_PATH = "utils/ik_teleop/urdf_template/allegro_right.urdf"

TRANS_HAND_TIPS = {
    'thumb': 6,
    'index': 7,
    'middle': 8,
    'ring': 9,
    'pinky': 10
}

class DexArmOp(object):
    def __init__(self, allegro_bound_path = os.path.join(os.getcwd(), "utils", "bound_data", "allegro_bounds.yaml"), cfg = None):
        # ROS subscribers
        self.hand_coords = None
        self.current_joint_state = None

        # Initializing IK solver
        self.ik_solver = AllegroIKController(cfg = self.cfg.allegro, urdf_path = URDF_PATH)

        # Moving robot to home position

        self.moving_average_queues = {
                'thumb': [],
                'index': [],
                'middle': [],
                'ring': []
            }

        with open(allegro_bound_path, 'r') as file:
            self.allegro_bounds = yaml.safe_load(file)['allegro_bounds']

    def _callback_hand_coords(self, hand_coords):
        self.hand_coords = np.array(list(hand_coords.data)).reshape(11, 2)

    def _callback_curr_joint_state(self, curr_joint_state):
        self.current_joint_state = list(curr_joint_state.position)

    def get_finger_tip_data(self):
        finger_tip_coords = {}

        for key in TRANS_HAND_TIPS.keys():
            finger_tip_coords[key] = self.hand_coords[TRANS_HAND_TIPS[key]]

        return finger_tip_coords

    def move(self):
        print("\n******************************************************************************")
        print("     Controller initiated. ")
        print("******************************************************************************\n")
        print("Start controlling the robot hand using the tele-op.\n")

        while True:
            if self.hand_coords is not None and self.current_joint_state is not None:
                finger_tip_coords = self.get_finger_tip_data()
                desired_joint_angles = copy(self.current_joint_state)

                # Movement for index finger
                desired_joint_angles = self.ik_solver.bounded_linear_finger_motion(
                    "index", 
                    self.allegro_bounds['height'], # X value 
                    self.allegro_bounds['index']['y'], # Y value
                    finger_tip_coords['index'][1], # Z value
                    self.calibrated_bounds[0], 
                    self.allegro_bounds['index']['z_bounds'], 
                    self.moving_average_queues['index'], 
                    desired_joint_angles
                )

                # # Movement for the Middle finger
                desired_joint_angles = self.ik_solver.bounded_linear_finger_motion(
                    "middle", 
                    self.allegro_bounds['height'], # X value 
                    self.allegro_bounds['middle']['y'], # Y value
                    finger_tip_coords['middle'][1], # Z value
                    self.calibrated_bounds[1], 
                    self.allegro_bounds['middle']['z_bounds'], 
                    self.moving_average_queues['middle'], 
                    desired_joint_angles
                )

                # Movement for the Ring finger using the ring and pinky fingers
                desired_joint_angles = self.ik_solver.bounded_linear_fingers_motion(
                    "ring", 
                    self.allegro_bounds['height'], 
                    finger_tip_coords['pinky'][1], 
                    finger_tip_coords['ring'][1], 
                    self.calibrated_bounds[3], # Pinky bound for Allegro Y axis movement
                    self.calibrated_bounds[2], # Ring bound for Allegro Z axis movement
                    self.allegro_bounds['ring']['y_bounds'], 
                    self.allegro_bounds['ring']['z_bounds'], 
                    self.moving_average_queues['ring'], 
                    desired_joint_angles
                )

                # Movement for the Thumb
                if cv2.pointPolygonTest(np.float32(self.calibrated_bounds[4:]), np.float32(finger_tip_coords['thumb'][:2]), False) > -1:
                    transformed_thumb_coordinate = perform_persperctive_transformation(
                        finger_tip_coords['thumb'],
                        self.calibrated_bounds[4 : ],
                        self.allegro_bounds['thumb'],
                        self.allegro_bounds['height']
                    )

                    desired_joint_angles = self.ik_solver.bounded_finger_motion(
                        "thumb",
                        transformed_thumb_coordinate,
                        self.moving_average_queues['thumb'],
                        desired_joint_angles
                    )

                # Publishing the required joint angles
                self.arm_controller.move_hand(desired_joint_angles)

                if cv2.waitKey(5) & 0xFF == 27:
                    break