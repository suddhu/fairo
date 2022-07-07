#!/usr/bin/env python
"""
Sudharshan Suresh, suddhu@fb.com
Connects to the robot and realsense, and runs the iSDF mapping from RGB-D
"""

import time, os
from os import path as osp
import hydra
import logging
from omegaconf import DictConfig, OmegaConf
import torch

abspath = os.path.abspath(__file__)
dname = os.path.dirname(abspath)
os.chdir(osp.join(dname, '..'))

log = logging.getLogger(__name__)
                                    
@hydra.main(config_path="../conf", config_name="run_isdf")
def main(cfg : DictConfig):
    print(f"Config:\n{OmegaConf.to_yaml(cfg, resolve=True)}")

    print("Initialize robot & gripper")
    robot = hydra.utils.instantiate(cfg.robot)

    while True:
        robot.go_home()
        time.sleep(2)
        state_log = robot.move_to_ee_pose(position = torch.Tensor([0.5, 0.5, 0.5]), orientation = None, time_to_go = 5)
        time.sleep(2)
        
if __name__ == "__main__":
    main()

