> Historical optional host guide. See README.md for the actual installed layout and operations. Do not reinstall the OS or switch desktop modes to use this deployment.

# Laptop Server Setup

This guide is for running the stack on a laptop with Ubuntu Server while keeping it suitable for 24/7 use.

## Recommended OS

Use:

```text
Ubuntu Server 24.04 LTS
```

Enable OpenSSH during installation so you can manage the laptop from another computer.

## Optional Toggleable Desktop

Install KDE Plasma only if you want local GUI access:

```bash
sudo apt update
sudo apt install kde-plasma-desktop
```

Use server/headless mode by default:

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

Start the desktop manually when needed:

```bash
sudo systemctl start graphical.target
```

Return to server/headless mode:

```bash
sudo systemctl isolate multi-user.target
```

Make the desktop start automatically again:

```bash
sudo systemctl set-default graphical.target
sudo reboot
```

## Disable Sleep

For a 24/7 server, disable suspend:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

If you use the laptop with the lid closed, edit:

```bash
sudo nano /etc/systemd/logind.conf
```

Set or add:

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
```

Apply it:

```bash
sudo systemctl restart systemd-logind
```

This host uses `/etc/systemd/logind.conf.d/60-storagecloud.conf` for those
settings, and the system sleep targets are masked.

## CPU Frequency

This ASUS laptop is capped at 1.8 GHz for cooler 24/7 server operation. The
active runtime value is:

```text
/sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq = 1800000
```

The persistent service is:

```bash
sudo systemctl status storagecloud-cpu-limit.service
```

Check the current policy with:

```bash
cpupower frequency-info
```

## Local SSH

OpenSSH Server is installed and enabled for management from another computer on
the home network.

Connect with:

```bash
ssh gasper@192.168.10.10
```

The server listens on port 22, password login is enabled, public-key login is
enabled, root login is disabled, and X11 forwarding is disabled. UFW is installed
but inactive; a LAN-only allow rule for `192.168.10.0/24` to TCP port 22 is
prepared if UFW is enabled later.

## Local Remote Desktop

GNOME Remote Desktop is enabled on the existing logged-in Wayland desktop. It
uses RDP on port 3389, mirrors the primary display, and allows remote keyboard
and mouse control.

Connect from another home-network computer with an RDP client:

```text
192.168.10.10:3389
```

Connection details are stored privately in:

```text
/home/gasper/.local/share/storagecloud/remote-desktop.json
```

If GNOME rejects the login, open **Settings -> System -> Remote Desktop** on
this laptop, keep Remote Desktop enabled, and set the login credentials there.
This Ubuntu/GNOME build may require the desktop keyring/UI to save the RDP
username and password.

GDM automatic login is enabled for `gasper` in `/etc/gdm3/custom.conf`, so the
same desktop session should come back after reboot. Do not log out for normal
server operation; lock the screen instead. User linger is enabled for `gasper`
so user services keep their systemd state across boot/session transitions.

For reliable same-session RDP on this laptop, GNOME screen blanking, dimming,
and locking are disabled. If the display goes black, Windows RDP can lose the
Wayland screen-share session.

```bash
gsettings get org.gnome.desktop.session idle-delay
gsettings get org.gnome.desktop.screensaver lock-enabled
gsettings get org.gnome.settings-daemon.plugins.power idle-dim
```

Expected values are `uint32 0`, `false`, and `false`.

When checking RDP from a VS Code snap terminal, use:

```bash
/home/gasper/storagecloud/scripts/check-rdp.sh
```

The snap environment can make plain `grdctl status --show-credentials` read the
wrong keyring and incorrectly report null credentials. GNOME Remote Desktop does
not have an idle logout timeout configured here. If Windows drops the session,
the server logs usually show it as a network/client disconnect, authentication
failure, or GNOME screen-share inhibition rather than a configured timeout.

## Battery Charge Limit

Limiting the battery to around 60% is a good idea for a plugged-in laptop server, but support depends on the laptop brand and firmware.

First check whether Linux exposes charge limit controls:

```bash
ls /sys/class/power_supply/BAT*
```

Then check for charge-control files:

```bash
ls /sys/class/power_supply/BAT0 | grep charge
```

If you see files like these, your laptop likely supports native limits:

```text
charge_control_start_threshold
charge_control_end_threshold
```

Set a 60% upper limit:

```bash
echo 55 | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold
echo 60 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```

If `BAT0` does not exist, check whether your battery is named `BAT1`:

```bash
ls /sys/class/power_supply/
```

## Make Battery Limit Persistent

Create a systemd service:

```bash
sudo nano /etc/systemd/system/battery-charge-limit.service
```

Paste:

```ini
[Unit]
Description=Set battery charge limit
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 55 > /sys/class/power_supply/BAT0/charge_control_start_threshold || true'
ExecStart=/bin/sh -c 'echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold || true'

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now battery-charge-limit.service
```

Check it:

```bash
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

## If Native Battery Limits Are Missing

Install TLP:

```bash
sudo apt install tlp tlp-rdw
```

Check battery support:

```bash
sudo tlp-stat -b
```

Edit TLP config:

```bash
sudo nano /etc/tlp.conf
```

For ThinkPad/Lenovo laptops that support thresholds, set:

```ini
START_CHARGE_THRESH_BAT0=55
STOP_CHARGE_THRESH_BAT0=60
```

Apply:

```bash
sudo systemctl enable --now tlp
sudo tlp start
```

Check:

```bash
sudo tlp-stat -b
```

## Vendor Notes

- Lenovo ThinkPad models often support charge thresholds well.
- Some Lenovo IdeaPad, Dell, HP, Acer, and ASUS models may not expose charge limits through Linux.
- Some laptops require setting battery conservation mode in BIOS/UEFI or the vendor app before installing Linux.
- If Linux cannot control the charge limit, the fallback is using a smart plug schedule, but native firmware control is better.

## Docker Storage Recommendation

On real Ubuntu Server, prefer bind mounts on a real storage disk instead of Docker Desktop-style named volumes.

Example paths:

```text
/mnt/storage/nextcloud
/mnt/storage/immich
```

For a future migration, update Compose volumes like:

```yaml
- /mnt/storage/nextcloud:/var/www/html/data
- /mnt/storage/immich:/data
```

Back up before changing storage paths.
