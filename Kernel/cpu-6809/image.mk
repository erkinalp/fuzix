fuzix.bin: target $(OBJS) tools/decbdragon tools/decb-image tools/visualizefcc tools/diskpad tools/hogfather
	+make -C platform/platform-$(TARGET) image
	(cd platform/platform-$(TARGET); ../../tools/visualizefcc < ../../fuzix.map)
	tools/hogfather fuzix.map | sort -nr >fuzix.hogs
