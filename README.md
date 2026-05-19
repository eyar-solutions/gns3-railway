# GNS3 on Railway

Run a full network lab in the cloud — no local install, no powerful hardware. Deploy GNS3 to [Railway](https://railway.app) in one click and open it in your browser.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/new/template?template=https://github.com/eyar-solutions/gns3-railway)

---

## What is this?

GNS3 is the industry-standard network simulator used by students, engineers, and labs worldwide. This template runs the full GNS3 stack on Railway — server, GUI, and all — and exposes it via a browser-based noVNC interface. No local software required.

### What comes pre-installed

| Appliance | Type | Image needed? |
|---|---|---|
| **FRRouting (FRR)** | Router | No — pulls from Docker Hub automatically |
| **Open vSwitch** | L2/L3 Switch | No — pulls from Docker Hub automatically |
| **OpenWRT** | Firewall | No — pulls from Docker Hub automatically |
| **Alpine Host** | PC / Endpoint | No — built at startup |
| **Cisco 3725** | Router | Yes — you supply the IOS `.bin` |
| **Cisco IOU L2** | L2 Switch | Yes — you supply the IOU L2 binary + license |
| **Cisco IOU L3** | L3 Switch | Yes — you supply the IOU L3 binary + license |

> Cisco images are not included due to vendor licensing. You must own a valid license to use them.

---

## Before you start

You will need:

1. A [Railway account](https://railway.app) — free tier is enough for small labs
2. *(Optional)* A Cisco IOS `.bin` file — `c3725-adventerprisek9-mz.124-15.T14.bin` is most common
3. *(Optional)* A Cisco IOU L2 binary and `iourc` license file

That's it. No local software to install.

---

## Step-by-step setup

### Step 1 — Deploy to Railway

Click the **Deploy on Railway** button above. When prompted, set two environment variables:

| Variable | What it is | Example |
|---|---|---|
| `GNS3_USER` | Your login username | `admin` |
| `GNS3_PASSWORD` | Your login password | `changeme` |

Use a strong password — your GNS3 server will be publicly reachable on the internet.

### Step 2 — Add a volume (important)

Without a volume, your projects and uploaded images will be deleted every time the container restarts.

1. In Railway, open your project → click your GNS3 service
2. Go to **Settings → Volumes → Add Volume**
3. Set the mount path to `/gns3`
4. Save and redeploy

### Step 3 — Enable privileged mode

The Docker-based appliances (FRR, OVS, OpenWRT, Alpine) need privileged mode to manage network interfaces.

1. In Railway, go to **Settings → Deploy**
2. Under **Container Options**, enable **Privileged**
3. Redeploy

### Step 4 — Open the browser UI

Railway will give your service a public URL (e.g. `https://gns3-railway-production.up.railway.app`).

Open that URL in your browser — you will see the full GNS3 desktop interface running via noVNC.

> The first load takes 15–30 seconds while all services start. If you see a blank screen, wait a moment and refresh.

---

## Adding Cisco images

### Cisco IOS router (`c3725`)

**Upload from your machine using the included script:**

```bash
./scripts/add-image.sh \
  --ios c3725-adventerprisek9-mz.124-15.T14.bin \
  --host YOUR_RAILWAY_HOST \
  --port 3080 \
  --user admin \
  --pass yourpassword
```

**Or upload through the browser GUI:**
1. In the GNS3 browser UI, go to **Edit → Preferences → Dynamips → IOS Routers → New**
2. Click **Browse** and select your `.bin` file
3. GNS3 will upload it to the server automatically

After adding the router to your topology, right-click it and choose **Idle-PC** to find a value that stops it using 100% CPU. A known good value for c3725 is `0x602467a4`.

---

### Cisco IOU L2 switch

You need two files:
- The IOU L2 binary (e.g. `i86bi_linux_l2-adventerprisek9-ms.SSA.high_iron_20180510.bin`)
- An `iourc` license file

**Upload the binary:**

```bash
./scripts/add-image.sh \
  --ios i86bi_linux_l2-adventerprisek9-ms.SSA.high_iron_20180510.bin \
  --host YOUR_RAILWAY_HOST \
  --port 3080 \
  --user admin \
  --pass yourpassword
```

**Upload the iourc license file** by mounting it via the Railway volume at `/gns3/images/IOU/iourc`.

**Register the switch in the browser GUI:**
1. Go to **Edit → Preferences → IOS on Unix → IOU Devices → New**
2. Browse to your IOU L2 binary
3. Set type to **L2 image**

---

### Cisco IOU L3 switch

Same process as IOU L2, using the IOU L3 binary (`i86bi_linuxl3-*.bin`). Set type to **L3 image** when registering.

**Enable L3 routing on the switch (in IOS CLI):**
```
ip routing
interface vlan 10
 ip address 192.168.10.1 255.255.255.0
router ospf 1
 network 192.168.0.0 0.0.255.255 area 0
```

---

## Adding any Docker image

Pull any Docker image into the live server to use it as a custom appliance:

```bash
./scripts/add-image.sh \
  --docker frrouting/frr:9.0 \
  --host YOUR_RAILWAY_HOST \
  --port 3080 \
  --user admin \
  --pass yourpassword
```

---

## Check what is loaded

```bash
./scripts/add-image.sh \
  --host YOUR_RAILWAY_HOST \
  --port 3080 \
  --user admin \
  --pass yourpassword \
  --list
```

---

## Starter topology

Build this lab by dragging nodes from the left panel in the browser GUI:

```
[Alpine Host A] --- [FRR Router A] --- [Open vSwitch] --- [FRR Router B] --- [Alpine Host B]
                          |
                    [OpenWRT FW]
                          |
                      (internet)
```

**Quick start commands:**

On FRR Router A (`vtysh`):
```
configure terminal
interface eth0
 ip address 10.0.1.1/30
interface eth1
 ip address 10.0.2.1/30
router ospf
 network 10.0.0.0/8 area 0
```

On Alpine Host A:
```sh
ip addr add 10.0.1.10/30 dev eth0
ip route add default via 10.0.1.1
ping 10.0.2.10
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `GNS3_USER` | `admin` | Login username |
| `GNS3_PASSWORD` | `admin` | Login password — change this before deploying |
| `GNS3_AUTH` | `True` | Set to `False` to disable login (not recommended) |

---

## How it works

The container runs four processes managed by supervisord:

| Process | Role |
|---|---|
| **Xvfb** | Virtual framebuffer — a headless display the GUI can render to |
| **x11vnc** | VNC server that captures that display |
| **noVNC / websockify** | Converts VNC to WebSocket and serves the browser UI on port 6080 |
| **GNS3 server** | Network simulation backend (REST API on port 3080) |
| **GNS3 GUI** | Full desktop GUI, launched on the virtual display |

Railway exposes port 6080 as the public HTTPS URL. Port 3080 is available for the `add-image.sh` script (requires Railway TCP proxy if used externally).

---

## What works and what does not

| Feature | Status | Why |
|---|---|---|
| FRR, OVS, OpenWRT, Alpine (Docker) | Works | No special hardware needed |
| Cisco IOS via Dynamips | Works | CPU-based emulation, no KVM |
| Cisco IOU L2 / L3 switch | Works | Native Linux binary, no KVM |
| Juniper vMX / vSRX | Does not work | Requires KVM |
| Cisco IOSv / ASAv | Does not work | Requires KVM |
| Browser access | Works | noVNC serves full GNS3 GUI in browser |
| Multiple users at once | Shared screen | All users see the same desktop |

For QEMU-based images (Juniper, ASAv, Palo Alto) you need a KVM-capable VPS (Hetzner, DigitalOcean, etc.) — this repo's Docker image works there too.

---

## Troubleshooting

**Browser shows a blank or loading screen**
- Wait 20–30 seconds on first boot — all services start sequentially
- Check Railway deployment logs for errors

**GNS3 GUI shows a setup wizard**
- Click through it and configure the server as `localhost:3080` with your credentials
- On the next restart it will connect automatically

**Docker appliances fail to start**
- Make sure privileged mode is enabled in Railway deploy settings

**Cisco router using 100% CPU**
- Right-click the router → **Idle-PC** → pick any suggested value
- For c3725, try `0x602467a4` as a starting point

**Images lost after redeploy**
- A volume must be attached at `/gns3` — without it nothing persists

**IOU switch fails to start**
- Check that your `iourc` file is at `/gns3/images/IOU/iourc`
- The license in `iourc` must match the hostname of the Railway container

---

## Project structure

```
gns3-railway/
├── Dockerfile                    # GNS3 server + GUI + Xvfb + VNC + noVNC
├── railway.toml                  # Railway build and deploy settings
├── docker-compose.yml            # For running and testing locally
├── alpine-host/
│   └── Dockerfile                # Alpine image with networking tools pre-installed
├── configs/
│   ├── gns3_server.conf.tpl      # GNS3 server config (credentials injected from env)
│   ├── gns3_gui.conf.tpl         # GNS3 GUI config (pre-connects to local server)
│   ├── supervisord.conf          # Process manager config (all services)
│   └── appliances/
│       ├── frr.gns3a
│       ├── cisco-3725.gns3a
│       ├── cisco-iou-l2.gns3a
│       ├── cisco-iou-l3.gns3a
│       ├── openvswitch.gns3a
│       ├── openwrt.gns3a
│       └── alpine.gns3a
└── scripts/
    ├── entrypoint.sh             # Startup: init dirs, seed appliances, start supervisord
    ├── pull-images.sh            # Pre-pulls Docker appliance images in background
    └── add-image.sh              # Upload IOS/IOU/Docker images to a live server
```

---

## License

MIT. Cisco IOS and IOU images are not included and remain the property of Cisco Systems. You are responsible for ensuring you have the appropriate licenses before using them.
