from colorsys import rgb_to_hls
import pyvista as pv
from pyvistaqt import BackgroundPlotter
from matplotlib import pyplot as plt
import numpy as np


class Visualizer(): 
    def __init__(self):
        self.vis = pv.Plotter(title = "iSDF point cloud")
        self.vis.set_background('white')
        self.vis.show(title='iSDF pointcloud', window_size=[800, 600], auto_close=False, interactive_update=True)
        
    def show_rgbd(self, rgb, depth, timestamp):
        plt.clf()
        plt.subplot(2, 1, 1)
        plt.imshow(rgb)
        plt.title('RGB ' + str(timestamp))
        plt.subplot(2, 1, 2)
        plt.imshow(depth)
        plt.title('Depth ' + str(timestamp))
        plt.draw()
        plt.pause(1e-6)

    def show_pointcloud(self, pcd):
        """Render a scene's pointcloud and return the Open3d Visualizer."""
        # visualize the pointcloud 
        point_cloud = pv.PolyData(np.array(pcd.points))
        colors = np.array(pcd.colors)
        dargs = dict(show_scalar_bar=False, opacity=1, scalars=colors, rgb=True)
        self.vis.clear()
        self.vis.add_mesh(point_cloud, point_size=10, **dargs)
        # Render and get time to render
        self.vis.update()