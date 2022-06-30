#!/usr/bin/env python
"""
Sudharshan Suresh, suddhu@fb.com
Connects to the robot and realsense, and runs the iSDF mapping from RGB-D
"""

import numpy as np
import time, os
import hydra

@hydra.main(config_path="../conf", config_name="run_isdf")
def main(cfg):
    print(f"Config:\n{omegaconf.OmegaConf.to_yaml(cfg, resolve=True)}")
    print(f"Current working directory: {os.getcwd()}")

    print("Initialize robot & gripper")
    robot = hydra.utils.instantiate(cfg.robot)
    robot.gripper_open()
    robot.go_home()

    print("Initializing cameras")
    cfg.cam.intrinsics_file = hydra.utils.to_absolute_path(cfg.cam.intrinsics_file)
    cfg.cam.extrinsics_file = hydra.utils.to_absolute_path(cfg.cam.extrinsics_file)
    cameras = hydra.utils.instantiate(cfg.cam)

    print("Loading camera workspace masks")
    masks_1 = np.array(
        [load_bw_img(hydra.utils.to_absolute_path(x)) for x in cfg.masks_1],
        dtype=np.float64,
    )
    masks_2 = np.array(
        [load_bw_img(hydra.utils.to_absolute_path(x)) for x in cfg.masks_2],
        dtype=np.float64,
    )

    print("Connect to grasp candidate selection and pointcloud processor")
    segmentation_client = SegmentationClient()
    grasp_client = GraspClient(
        view_json_path=hydra.utils.to_absolute_path(cfg.view_json_path)
    )

    root_working_dir = os.getcwd()
    for outer_i in range(cfg.num_bin_shifts):
        cam_i = outer_i % 2
        print(f"=== Starting bin shift with cam {cam_i} ===")

        # Define some parameters for each workspace.
        if cam_i == 0:
            masks = masks_1
            hori_offset = torch.Tensor([0, -0.4, 0])
        else:
            masks = masks_2
            hori_offset = torch.Tensor([0, 0.4, 0])
        time_to_go = 3

        for i in range(cfg.num_grasps_per_bin_shift):
            # Create directory for current grasp iteration
            os.chdir(root_working_dir)
            timestamp = int(time.time())
            os.makedirs(f"{timestamp}")
            os.chdir(f"{timestamp}")

            print(
                f"=== Grasp {i + 1}/{cfg.num_grasps_per_bin_shift}, logging to"
                f" {os.getcwd()} ==="
            )

            print("Getting rgbd and pcds..")
            rgbd = cameras.get_rgbd()

            rgbd_masked = rgbd * masks[:, :, :, None]
            scene_pcd = cameras.get_pcd(rgbd)
            save_rgbd_masked(rgbd, rgbd_masked)

            print("Segmenting image...")
            unmerged_obj_pcds = []
            for i in range(cameras.n_cams):
                obj_masked_rgbds, obj_masks = segmentation_client.segment_img(
                    rgbd_masked[i], min_mask_size=cfg.min_mask_size
                )
                unmerged_obj_pcds += [
                    cameras.get_pcd_i(obj_masked_rgbd, i)
                    for obj_masked_rgbd in obj_masked_rgbds
                ]
            print(
                f"Merging {len(unmerged_obj_pcds)} object pcds by clustering their centroids"
            )
            obj_pcds = merge_pcds(unmerged_obj_pcds)
            if len(obj_pcds) == 0:
                print(
                    f"Failed to find any objects with mask size > {cfg.min_mask_size}!"
                )
                break

            print("Getting grasps per object...")
            obj_i, filtered_grasp_group = grasp_client.get_obj_grasps(
                obj_pcds, scene_pcd
            )

            print("Choosing a grasp for the object")
            final_filtered_grasps, chosen_grasp_i = robot.select_grasp(
                filtered_grasp_group
            )
            chosen_grasp = final_filtered_grasps[chosen_grasp_i]

            grasp_client.visualize_grasp(scene_pcd, final_filtered_grasps)
            grasp_client.visualize_grasp(
                obj_pcds[obj_i], final_filtered_grasps, name="obj"
            )

            traj = execute_grasp(robot, chosen_grasp, hori_offset, time_to_go)

            print("Going home")
            robot.go_home()


if __name__ == "__main__":
    main()

