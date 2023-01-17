# Franka iSDF

## Installation

```bash
pip install mrp
git submodule update --init --recursive .
mrp up --norun
```

## Download weights

```bash
./scripts/download_weights.sh
```

## Usage

Ensure Polymetis is running on the machine connected to the robot. Then, start the necessary pointcloud/grasping/gripper servers:

```bash
mrp up
mrp ps  # Ensure processes are alive
mrp logs --old  # Check logs
```

The example script to bring everything together and execute the grasps:

```bash
conda activate mrp_franka_isdf
python scripts/run_isdf.py  # Connect to robot, gripper, servers; run grasp
```
# github personal access token = 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