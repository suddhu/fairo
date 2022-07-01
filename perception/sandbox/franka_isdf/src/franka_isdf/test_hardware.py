from ipaddress import ip_address
from turtle import position 
# from polymetis import RobotInterface
import torch 
import time

# robot = RobotInterface(ip_address = '172.16.0.1', enforce_version = False)
# print('Going home!')
# robot.go_home()
# time.sleep(2)
# state_log = robot.move_to_ee_pose(position = torch.Tensor([0.5, 0.5, 0.5]), orientation = None, time_to_go = 5)
# print(state_log)
# time.sleep(2)
# robot.go_home()

from realsense_wrapper import RealsenseAPI
time.sleep(2)
rs = RealsenseAPI()

num_cameras = rs.get_num_cameras()
intrinsics = rs.get_intrinsics()

print(f"Num cameras : {num_cameras}, intrinsics: {intrinsics}")
rgbd = rs.get_rgbd()