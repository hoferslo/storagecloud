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
```

Apply it:

```bash
sudo systemctl restart systemd-logind
```

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
- /mnt/storage/immich:/usr/src/app/upload
```

Back up before changing storage paths.
