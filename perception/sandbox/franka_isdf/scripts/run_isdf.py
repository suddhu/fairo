#!/usr/bin/env python
"""
Sudharshan Suresh, suddhu@fb.com
Connects to the robot and realsense, and runs the iSDF mapping from RGB-D
"""

import numpy as np
import time, os, datetime
from os import path as osp
import hydra
import logging
from omegaconf import DictConfig, OmegaConf
import torch
from franka_isdf.visualizer import Visualizer

abspath = os.path.abspath(__file__)
dname = os.path.dirname(abspath)
os.chdir(osp.join(dname, '..'))

log = logging.getLogger(__name__)
# fig = plt.figure(figsize=(12, 8))

                                    
@hydra.main(config_path="../conf", config_name="run_isdf")
def main(cfg : DictConfig):
    print(f"Config:\n{OmegaConf.to_yaml(cfg, resolve=True)}")

    # make folders for recording data 
    isdf_path = '/mnt/tmp_nfs_clientshare/suddhu/isdf_data'
    datetime_folder = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    savepath = osp.join(isdf_path, datetime_folder)
    rgb_path = osp.join(savepath, "images")
    depth_path = osp.join(savepath, "depth")
    cloud_path = osp.join(savepath, "cloud")

    os.makedirs(savepath)
    os.makedirs(rgb_path)
    os.makedirs(depth_path)
    os.makedirs(cloud_path)

    print("Initialize robot & gripper")
    robot = hydra.utils.instantiate(cfg.robot)
    robot.go_home()

    # time.sleep(2)
    # state_log = robot.move_to_ee_pose(position = torch.Tensor([0.5, 0.5, 0.5]), orientation = None, time_to_go = 5)

    print("Initializing cameras")
    cfg.cam.intrinsics_file = hydra.utils.to_absolute_path(cfg.cam.intrinsics_file)
    cfg.cam.extrinsics_file = hydra.utils.to_absolute_path(cfg.cam.extrinsics_file)
    cameras = hydra.utils.instantiate(cfg.cam)

    print("Getting rgbd and pcds..")

    vis = Visualizer()
    while True: 
        timestamp = int(time.time())
        rgbd = cameras.get_rgbd()
        rgb = rgbd[0, :, :, :3]
        depth = rgbd[0, :, :, 3]
        scene_pcd = cameras.get_pcd(rgbd)
        down_pcd = scene_pcd.voxel_down_sample(voxel_size=0.01)
        vis.show_pointcloud(pcd = down_pcd)
        vis.show_rgbd(rgb = rgb, depth = depth, timestamp = timestamp)
        
if __name__ == "__main__":
    main()

