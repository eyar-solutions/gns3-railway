# Persistent Volume

Mount a Railway volume at `/gns3`. On first boot the entrypoint creates this layout:

```
/gns3/
├── images/
│   ├── IOS/        ← Cisco IOS .bin files (Dynamips)
│   ├── QEMU/       ← QEMU disk images (needs KVM — not available on Railway)
│   └── IOU/        ← Cisco IOU images
├── projects/       ← GNS3 project files (.gns3, topologies)
├── appliances/     ← Custom .gns3a appliance definitions
└── configs/        ← Startup configs for devices
```

## Adding IOS images at runtime

Upload a Cisco IOS .bin file to the running container:

```bash
# Copy a local image into the container
docker cp c3725-adventerprisek9-mz.124-15.T14.bin <container>:/gns3/images/IOS/

# Or use the GNS3 REST API
curl -u admin:password \
  -F "file=@c3725-adventerprisek9-mz.124-15.T14.bin" \
  http://<railway-host>/v2/compute/dynamips/images/upload/c3725-adventerprisek9-mz.124-15.T14.bin
```

## Notes

- Cisco/Juniper images are NOT included due to licensing. You must supply your own.
- Docker appliances (FRR, OpenWRT) do not require images — they pull from Docker Hub.
- QEMU images (vMX, vSRX, ASAv) require KVM and **will not work** on Railway.
