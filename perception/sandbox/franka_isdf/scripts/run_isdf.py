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
# import open3d as o3d
from matplotlib import pyplot as plt
from mpl_toolkits.mplot3d import proj3d

log = logging.getLogger(__name__)
fig = plt.figure(figsize=(12, 8))

# vis = o3d.visualization.Visualizer()
# vis.create_window(visible = True)
def save_img(img, name):
    f = plt.figure()
    plt.imshow(img)
    f.savefig(f"{name}.png")
    plt.close(f)

def show_img(rgb, depth, timestamp):
    plt.clf()
    plt.subplot(2, 2, 1)
    plt.imshow(rgb)
    plt.title('RGB ' + str(timestamp))
    plt.subplot(2, 2, 3)
    plt.imshow(depth)
    plt.title('Depth ' + str(timestamp))
    plt.draw()
    plt.pause(1e-6)

def save_pointcloud(scene_pcd, name):
    """Render a scene's pointcloud and return the Open3d Visualizer."""
    # vis = o3d.visualization.Visualizer()
    # vis.create_window(visible=True)
    # vis.add_geometry(scene_pcd)
    # vis.run()
    # vis.destroy_window()
    # Save scene
    # vis.capture_screen_image(f"{name}.png")
    # vis.destroy_window()

    skip = 100  

    plt.subplot(1, 2, 2, projection='3d')
    point_cloud = np.asarray(scene_pcd.points)
    x = point_cloud[::skip, 0]
    y = point_cloud[::skip, 1]
    z = point_cloud[::skip, 2]

    print(x)
    # ax = fig.add_subplot(111, projection='3d')
    plt.scatter(x, y, z)
    plt.draw()
    plt.pause(1e-6)

    # vis.update_geometry(scene_pcd)
    # vis.poll_events()
    # vis.update_renderer()
    # time.sleep(1)
                                    
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
    while True: 
        timestamp = int(time.time())
        rgbd = cameras.get_rgbd()
        rgb = rgbd[0, :, :, :3]
        depth = rgbd[0, :, :, 3]
        scene_pcd = cameras.get_pcd(rgbd)

        print(len(scene_pcd.points))

        # os.chdir(rgb_path)
        # save_img(rgb, name = timestamp)
        # os.chdir(depth_path)
        # save_img(depth, name = timestamp)
        os.chdir(cloud_path)
        show_img(rgb = rgb, depth = depth, timestamp= timestamp)
        save_pointcloud(scene_pcd, name = timestamp)

if __name__ == "__main__":
    main()

