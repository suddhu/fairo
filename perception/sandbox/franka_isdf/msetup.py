import mrp

franka_setup_commands = [
    ["pip", "install", "-e", "../../../msg"],
    ["pip", "install", "-e", "../../realsense_driver"],
    ["pip", "install", "-e", "./third_party/iSDF"],
    ["pip", "install", "-e", "./third_party/tacto"],
    ["pip", "install", "-e", "."],
]

franka_isdf_shared_env = mrp.Conda.SharedEnv(
    "franka_isdf",
    channels=["pytorch", "fair-robotics", "aihabitat", "conda-forge"],
    dependencies=["polymetis"],
    setup_commands=franka_setup_commands,
    yaml = "./third_party/iSDF/environment.yml"
)

mrp.process(
    name="cam_pub",
    runtime=mrp.Conda(
        shared_env=franka_isdf_shared_env,
        run_command=["python", "-m", "franka_isdf.cam_pub_sub"],
    ),
)

mrp.main()
