#!/usr/bin/env python

import pickle
from realsense_wrapper import RealsenseAPI
import time
import numpy as np
import sys

import os 
from os import path as osp

rs = RealsenseAPI()
time_stamp = 0
pathISDF = '/mnt/tmp_nfs_clientshare/suddhu/isdf_data'

# make folder for recording data 
# make folders for RGB-D
# make folders to record robot end effector data 

while True:
    time_stamp += 1
    imgs = rs.get_rgbd()
    raw_intrinsics = rs.get_intrinsics()
    raw_intrinsics = rs.get_intrinsics()
    intrinsics = []
    for intrinsics_param in raw_intrinsics:
        intrinsics.append(
            dict([(p, getattr(intrinsics_param, p)) for p in dir(intrinsics_param) if not p.startswith('__')])
        )

    with open(osp.join(pathISDF, f"traj_rgbd_{time_stamp}.pkl"), 'wb+') as fp:
        pickle.dump({"rgbd":imgs,},fp)

    # else:
    #     input("press ent")
    #     sys.exit("Trajectories complete, system exiting...")
        # write the imgs to {time_stamp}_rgbd.pkl
        # write cam_pose to {time_stamp}_cam_pose.pkl