#!/usr/bin/env python

import pickle
from realsense_wrapper import RealsenseAPI
import time
import numpy as np
import sys
import matplotlib.pyplot as plt
from cam_pub_sub import CameraSubscriber
import hydra

import os, datetime
from os import path as osp

rs = RealsenseAPI()
time_stamp = 0

# make folders for recording data 
isdf_path = '/mnt/tmp_nfs_clientshare/suddhu/isdf_data'
datetime_folder = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
savepath = osp.join(isdf_path, datetime_folder)
rgb_path = osp.join(savepath, "images")
depth_path = osp.join(savepath, "depth")
os.makedirs(savepath)
os.makedirs(rgb_path)
os.makedirs(depth_path)

# cam_sub = CameraSubscriber(intrinsics_file = 'conf/intrinsics.json', extrinsics_file=)
# make folders to record robot end effector data 

# fig, axs = plt.subplots(2, 1)
plt.figure(1)

while True:
    time_stamp += 1
    rgbd = rs.get_rgbd()
    raw_intrinsics = rs.get_intrinsics()
    raw_intrinsics = rs.get_intrinsics()
    intrinsics = []
    for intrinsics_param in raw_intrinsics:
        intrinsics.append(
            dict([(p, getattr(intrinsics_param, p)) for p in dir(intrinsics_param) if not p.startswith('__')])
        )

    rgb = rgbd[0, :, :, :3]
    depth = rgbd[0, :, :, 3]

    # Apply colormap on depth image (image must be converted to 8-bit per pixel first)
    # depth_colormap = cv2.applyColorMap(cv2.convertScaleAbs(depth, alpha=0.03), cv2.COLORMAP_JET)

    # depth_colormap_dim = depth_colormap.shape
    # rgb_colormap_dim = rgb.shape

    # # If depth and color resolutions are different, resize color image to match depth image for display
    # if depth_colormap_dim != rgb_colormap_dim:
    #     resized_color_image = cv2.resize(rgb, dsize=(depth_colormap_dim[1], depth_colormap_dim[0]), interpolation=cv2.INTER_AREA)
    #     images = np.hstack((resized_color_image, depth_colormap))
    # else:
    #     images = np.hstack((rgb, depth_colormap))

    # Show images
    # cv2.namedWindow('RealSense', cv2.WINDOW_AUTOSIZE)
    # cv2.imshow('RealSense', images)
    # cv2.waitKey(0)

    # plt.close()
    # axs[0].imshow(rgb)
    # axs[0].set_title("RGB")
    # axs[1].imshow(depth, cmap="prism")
    # axs[1].set_title("Depth")
    # fig.show()
    # time.sleep(10)
    # plt.subplot(2, 1, 1)
    # plt.imshow(rgb)
    # plt.title('RGB ' + str(time_stamp))
    # plt.subplot(2, 1, 2)
    # plt.imshow(depth)
    # plt.title('Depth ' + str(time_stamp))
    # plt.draw()
    # plt.pause(1e-6)
    # plt.clf()
    print(time_stamp)

    # with open(osp.join(pathISDF, f"traj_rgbd_{time_stamp}.pkl"), 'wb+') as fp:
    #     pickle.dump({"rgbd":imgs,},fp)

    # else:
    #     input("press ent")
    #     sys.exit("Trajectories complete, system exiting...")
        # write the imgs to {time_stamp}_rgbd.pkl
        # write cam_pose to {time_stamp}_cam_pose.pkl