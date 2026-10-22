import json
GPU='0000:02:00_0_0000:03:00_0'; CPU='pci0000:00_0000:00:18_3'; NCT='platform_nct6775_656'
DIMMS=[('i2c_18_18_0051','DIMM 1'),('i2c_18_18_0053','DIMM 2')]; SSDS=[('nvme_nvme0','500 GB SSD'),('nvme_nvme1','2 TB SSD')]
DS={"type":"prometheus","uid":"prometheus"}
panels=[]; y=0; nid=[0]; dest=[panels]; collapsed_at=[None]
def pid(): nid[0]+=1; return nid[0]
def row(title,collapsed=False):
    # A collapsed row carries its panels inside itself and takes one grid line;
    # the panels keep the y they would have had, which Grafana shifts on expand.
    global y
    if collapsed_at[0] is not None: y=collapsed_at[0]
    r={"id":pid(),"type":"row","title":title,"collapsed":collapsed,"gridPos":{"x":0,"y":y,"w":24,"h":1},"panels":[]}
    panels.append(r); y+=1
    dest[0]=r["panels"] if collapsed else panels; collapsed_at[0]=y if collapsed else None
def add(p): dest[0].append(p); return p
def tgt(expr,legend="",ref="A",instant=False):
    t={"datasource":DS,"expr":expr,"legendFormat":legend,"refId":ref}
    if instant: t["instant"]=True; t["range"]=False
    return t
def steps(thresholds,base="green"): return {"mode":"absolute","steps":[{"color":base,"value":None}]+[{"color":c,"value":v} for v,c in (thresholds or [])]}
def ts(title,targets,x,w,h=8,unit=None,desc=None,thresholds=None,min=None,max=None,fill=12,stack=False,overrides=None,calcs=None,bars=False,timeFrom=None,interval=None):
    fc={"defaults":{"custom":{"fillOpacity":fill,"gradientMode":"opacity","lineWidth":2,"showPoints":"never"},"color":{"mode":"palette-classic"}},"overrides":overrides or []}
    if unit: fc["defaults"]["unit"]=unit
    if min is not None: fc["defaults"]["min"]=min
    if max is not None: fc["defaults"]["max"]=max
    if stack: fc["defaults"]["custom"]["stacking"]={"mode":"normal"}
    if bars: fc["defaults"]["custom"].update(drawStyle="bars",fillOpacity=70,gradientMode="none",lineWidth=1)
    if thresholds:
        fc["defaults"]["custom"]["thresholdsStyle"]={"mode":"dashed"}
        fc["defaults"]["thresholds"]=steps(thresholds,"transparent")
    legend={"displayMode":"table","placement":"right","calcs":calcs} if calcs else {"displayMode":"list","placement":"bottom"}
    p={"id":pid(),"type":"timeseries","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
       "options":{"legend":legend,"tooltip":{"mode":"multi","sort":"desc"}},
       "targets":[dict(t,refId=chr(65+i)) for i,t in enumerate(targets)]}
    if desc: p["description"]=desc
    if timeFrom: p["timeFrom"]=timeFrom; p["hideTimeOverride"]=False
    if interval: p["interval"]=interval
    return add(p)
def stat(title,expr,x,w,h=4,unit=None,thresholds=None,decimals=None,desc=None,legend="",base="green",spark=True,instant=False,mappings=None,noValue=None):
    fc={"defaults":{"thresholds":steps(thresholds,base),"color":{"mode":"thresholds"}},"overrides":[]}
    if unit: fc["defaults"]["unit"]=unit
    if decimals is not None: fc["defaults"]["decimals"]=decimals
    if mappings: fc["defaults"]["mappings"]=[{"type":"value","options":{str(k):{"text":v[0],"color":v[1],"index":i} for i,(k,v) in enumerate(mappings.items())}}]
    if noValue: fc["defaults"]["noValue"]=noValue
    p={"id":pid(),"type":"stat","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
       "options":{"colorMode":"value","graphMode":"area" if spark and not instant else "none","justifyMode":"center","reduceOptions":{"calcs":["lastNotNull"]},"textMode":"value"},
       "targets":[tgt(expr,legend,instant=instant)]}
    if desc: p["description"]=desc
    return add(p)
def bar(title,targets,x,w,h=8,unit="percent",max=100,thresholds=None,desc=None,overrides=None,calc="lastNotNull"):
    fc={"defaults":{"unit":unit,"min":0,"thresholds":steps(thresholds),"color":{"mode":"thresholds"}},"overrides":overrides or []}
    if max is not None: fc["defaults"]["max"]=max
    p={"id":pid(),"type":"bargauge","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
       "options":{"orientation":"horizontal","displayMode":"gradient","valueMode":"color","showUnfilled":True,"namePlacement":"left","reduceOptions":{"calcs":[calc]}},
       "targets":[dict(t,refId=chr(65+i)) for i,t in enumerate(targets)]}
    if desc: p["description"]=desc
    return add(p)
def by_name(name,**props): return {"matcher":{"id":"byName","options":name},"properties":[{"id":k.replace("__","."),"value":v} for k,v in props.items()]}
def by_regex(rx,**props): return {"matcher":{"id":"byRegexp","options":rx},"properties":[{"id":k.replace("__","."),"value":v} for k,v in props.items()]}
def dashed(name,color): return by_name(name,custom__lineStyle={"fill":"dash","dash":[10,10]},color={"mode":"fixed","fixedColor":color},custom__fillOpacity=0)
def temp(chip,sensor="temp1"): return f'node_hwmon_temp_celsius{{chip="{chip}",sensor="{sensor}"}}'

DIMM_MAX='max(node_hwmon_temp_celsius{chip=~"i2c_.*"})'
ROOM='max(govee_temperature_celsius)'
FANS=f'avg(node_hwmon_pwm{{chip="{NCT}"}}) / 255 * 100'
GPU_W=f'sum(node_hwmon_power_average_watt{{chip="{GPU}"}})'
CPU_W='sum(rate(node_rapl_package_joules_total[1m]))'
WALL='max(tapo_power_watts)'
# A reboot is a new boot time. The value jitters by a second between scrapes,
# so count changes of it in 10-minute buckets instead of raw changes.
REBOOTS='changes(floor(node_boot_time_seconds / 600)[$__range:1m])'

# ── Now ──
row("Now")
stat("Wall Power",WALL,0,3,unit="watt",decimals=0,thresholds=[(250,"orange"),(450,"red")],desc="Measured at the socket, so it includes PSU losses and the monitor if it shares the plug.")
stat("CPU",'100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)',3,3,unit="percent",decimals=0,thresholds=[(70,"orange"),(90,"red")])
stat("Memory","(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",6,3,unit="percent",decimals=0,thresholds=[(80,"orange"),(92,"red")],desc="Includes the ZFS ARC, which the kernel does not count as available but gives back under pressure.")
stat("CPU Temp",temp(CPU),9,3,unit="celsius",decimals=0,thresholds=[(80,"orange"),(89,"red")],desc="Tctl; the 7800X3D throttles at 89 °C.")
stat("GPU Hotspot",temp(GPU,"temp2"),12,3,unit="celsius",decimals=0,thresholds=[(95,"orange"),(105,"red")],desc="Junction limit is 110 °C.")
stat("Hottest DIMM",DIMM_MAX,15,3,unit="celsius",decimals=0,thresholds=[(55,"orange"),(60,"red")],
     desc="Keep below 60 °C. At 72 °C this kit corrupts data under sustained load (2026-10-09); fan-control ramps the case fans from 50 °C to full at 62 °C.")
stat("Case Fans",FANS,18,3,unit="percent",decimals=0,thresholds=[(60,"orange"),(90,"red")],desc="Duty fan-control commands on every header (35 % floor).")
stat("Room",ROOM,21,3,unit="celsius",decimals=1,thresholds=[(26,"orange"),(30,"red")])
y+=4
stat("Uptime","node_time_seconds - node_boot_time_seconds",0,3,unit="s",spark=False)
stat("Reboots in Range",REBOOTS,3,3,decimals=0,instant=True,thresholds=[(1,"orange"),(3,"red")],
     desc="Boots inside the selected time range. Every one is also a dashed marker on the graphs; an unplanned one is a hang or reset, so cross-check `journalctl --list-boots`.")
stat("Failed Units",'count(node_systemd_unit_state{state="failed"} == 1) or vector(0)',6,3,decimals=0,spark=False,thresholds=[(1,"red")])
stat("Energy Today","max(tapo_energy_today_kwh)",9,3,unit="kwatth",decimals=2,spark=False)
stat("Idle Floor (7 d)","quantile_over_time(0.05, tapo_power_watts[7d])",12,3,unit="watt",decimals=0,instant=True,base="blue",
     desc="The lowest 5 % of wall readings over the last week: what the box draws doing nothing. The number to watch when tuning idle power.")
stat("DIMM > 60 °C",f'sum_over_time(({DIMM_MAX} > bool 60)[$__range:1m]) * 60',15,3,unit="s",decimals=0,instant=True,thresholds=[(1,"orange"),(600,"red")],
     desc="Time in the selected range the hottest DIMM spent above 60 °C. Should stay at zero.")
stat("Clock Error","node_timex_estimated_error_seconds",18,3,unit="s",decimals=1,thresholds=[(0.05,"orange"),(0.5,"red")],
     desc="chrony's estimate of how far the system clock is from true time, either direction. The Stability row has the history and the drift rate.")
stat("Humidity","max(govee_humidity_percent)",21,3,unit="percent",decimals=0,thresholds=[(60,"orange"),(70,"red")],desc="40-60 % is the comfortable band; above 60 % for long stretches is where mould starts.")
y+=4

# ── Cooling ──
row("Cooling")
ts("DIMMs vs Case Fans",[tgt(temp(c),n) for c,n in DIMMS]+[tgt(FANS,"case fans")],0,12,unit="celsius",thresholds=[(60,"red")],
   desc="The DIMMs are the part that fails first here. fan-control (hosts/orchid/system/fan-control.nix) drives every case fan from the hotter DIMM (50 → 62 °C) or the CPU (65 → 88 °C), whichever asks for more. Fans on the right axis.",
   overrides=[by_name("case fans",unit="percent",min=0,max=100,custom__axisPlacement="right",custom__fillOpacity=0,custom__thresholdsStyle={"mode":"off"},custom__lineStyle={"fill":"dash","dash":[4,4]},color={"mode":"fixed","fixedColor":"text"})],calcs=["mean","max","lastNotNull"])
ts("Heat Above Room",[tgt(f'{temp(CPU)} - on() group_left() {ROOM}',"CPU"),tgt(f'{temp(GPU,"temp1")} - on() group_left() {ROOM}',"GPU edge"),
   tgt(f'{DIMM_MAX} - on() group_left() {ROOM}',"hottest DIMM"),tgt(f'max(node_hwmon_temp_celsius{{chip=~"nvme_.*",sensor="temp1"}}) - on() group_left() {ROOM}',"hottest SSD")],12,12,unit="celsius",
   desc="Each component minus the room temperature, so a hot afternoon doesn't look like a cooling problem. A rise here at the same load, over weeks, is dust or a drying paste.",calcs=["mean","max"])
y+=8
ts("Fan Speeds",[tgt(f'label_replace(node_hwmon_fan_rpm{{chip="{NCT}"}} > 0, "n", "$1", "sensor", "fan(\\\\d+)")',"case fan {{n}}")],0,12,unit="rpm",min=0,calcs=["mean","max","lastNotNull"],
   desc="Measured speed of every header with a fan on it. The GPU's own fans aren't here: its tach reads 0 under amdgpu, see the GPU row.")
bar("Peak Temperatures in Range",[tgt(f'max_over_time({temp(CPU)}[$__range])',"CPU",instant=True),tgt(f'max_over_time({temp(GPU,"temp2")}[$__range])',"GPU hotspot",instant=True),
    tgt(f'max_over_time({temp(GPU,"temp3")}[$__range])',"GPU memory",instant=True),tgt(f'max_over_time({DIMM_MAX}[$__range:1m])',"DIMMs",instant=True),
    tgt(f'max_over_time(max(node_hwmon_temp_celsius{{chip=~"nvme_.*"}})[$__range:1m])',"SSDs",instant=True)],12,12,unit="celsius",max=110,
    desc="The hottest each part got in the selected range, coloured against its own limit: CPU throttles at 89, GPU hotspot 110, GPU memory ~105, DIMMs fail past ~65, SSDs throttle at ~80.",
    overrides=[by_name("CPU",thresholds=steps([(80,"orange"),(89,"red")])),by_name("GPU hotspot",thresholds=steps([(95,"orange"),(105,"red")])),
               by_name("GPU memory",thresholds=steps([(90,"orange"),(100,"red")])),by_name("DIMMs",thresholds=steps([(55,"orange"),(60,"red")])),
               by_name("SSDs",thresholds=steps([(70,"orange"),(80,"red")]))])
y+=8

# ── Power ──
row("Power & Energy")
stat("This Month","max(tapo_energy_month_kwh)",0,4,unit="kwatth",decimals=1,spark=False,base="blue")
stat("Energy in Range","avg_over_time(tapo_power_watts[$__range]) * $__range_s / 3600 / 1000",4,4,unit="kwatth",decimals=2,instant=True,base="blue",
     desc="Mean wall power over the selected range × its length. Gaps where the plug didn't answer are left out of the mean, not counted as 0 W.")
stat("Mean Power in Range","avg_over_time(tapo_power_watts[$__range])",8,4,unit="watt",decimals=0,instant=True,base="blue")
stat("Peak Power in Range","max_over_time(tapo_power_watts[$__range])",12,4,unit="watt",decimals=0,instant=True,thresholds=[(450,"orange"),(600,"red")])
stat("GPU Share of Wall",f'{GPU_W} / {WALL} * 100',16,4,unit="percent",decimals=0,base="blue")
stat("CPU Share of Wall",f'{CPU_W} / {WALL} * 100',20,4,unit="percent",decimals=0,base="blue")
y+=4
ts("Where the Watts Go",[tgt(GPU_W,"GPU"),tgt(CPU_W,"CPU package"),tgt(f'clamp_min({WALL} - {GPU_W} - {CPU_W}, 0)',"rest of the system"),tgt(WALL,"wall")],0,16,unit="watt",min=0,stack=True,fill=35,
   desc="GPU and CPU as they report themselves, and the rest of the wall reading: board, DIMMs, SSDs, fans, the iGPU, PSU conversion loss and anything else on the same plug. The stack adds up to the wall line.",
   overrides=[by_name("wall",custom__stacking={"mode":"none","group":"wall"},custom__fillOpacity=0,color={"mode":"fixed","fixedColor":"text"},custom__lineWidth=1)],calcs=["mean","max"])
ts("Energy per Day",[tgt("avg_over_time(tapo_power_watts[$__interval]) * 24 / 1000","kWh")],16,8,unit="kwatth",min=0,bars=True,timeFrom="30d",interval="1d",
   desc="Last 30 days, from the mean wall power of each day × 24 h. Each bar sits at the end of the day it covers.")
y+=8

# ── Stability ──
row("Stability")
ts("Uptime (30 d)",[tgt("(node_time_seconds - node_boot_time_seconds) / 86400","days up")],0,12,unit="d",min=0,fill=25,timeFrom="30d",
   desc="Each drop to zero is a boot; a gap before it is time the box was dead (a hang, then a power-cycle). A planned reboot has no gap.")
ts("Pressure Stall",[tgt("rate(node_pressure_cpu_waiting_seconds_total[2m])","CPU"),tgt("rate(node_pressure_io_waiting_seconds_total[2m])","IO"),tgt("rate(node_pressure_memory_waiting_seconds_total[2m])","memory"),tgt("rate(node_pressure_memory_stalled_seconds_total[2m])","memory (all stalled)")],12,12,unit="percentunit",min=0,
   desc="Share of wall time at least one task waited on the resource: how much the machine felt slow, whatever the cause. Memory 'all stalled' near 100 % is swap death, the one software failure that looks like a hang.",calcs=["mean","max"])
y+=8
stat("Booted at","node_boot_time_seconds * 1000",0,4,unit="dateTimeAsIso",spark=False)
stat("OOM Kills (since boot)","node_vmstat_oom_kill",4,4,decimals=0,spark=False,thresholds=[(1,"red")])
stat("Swap Used","node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes",8,4,unit="bytes",decimals=1,thresholds=[(1e9,"orange"),(8e9,"red")])
stat("ZFS Pool","node_zfs_zpool_state{zpool=\"rpool\",state=\"online\"}",12,4,spark=False,base="red",mappings={1:("online","green"),0:("degraded","red")})
stat("systemd","node_systemd_system_running",16,4,spark=False,base="red",mappings={1:("running","green"),0:("degraded","red")})
# Not node_timex_sync_status: chrony keeps the kernel's STA_UNSYNC flag set on
# purpose (clearing it turns on the kernel's 11-minute RTC writes, which would
# fight chrony's own RTC trimming), so that metric reads 0 forever. chrony
# raises maxerror to 16 s when unsynchronised, and systemd-timedated uses the
# same < 16 s rule for timedatectl's "synchronized: yes".
stat("Clock","node_timex_maxerror_seconds < bool 16",20,4,spark=False,base="red",mappings={1:("synced","green"),0:("not synced","red")},
     desc="Whether chrony has the clock synchronised to network time: the kernel's max error is under 16 s, the same test timedatectl uses.")
y+=4
ts("Clock Error",[tgt("node_timex_estimated_error_seconds","estimated error"),tgt("node_timex_maxerror_seconds","max error")],0,12,unit="s",calcs=["min","max","lastNotNull"],
   desc="Estimated error is chrony's best guess at how far the clock is from true time. Max error is its worst-case bound (mostly half the round-trip delay to the servers); it grows while no sync arrives and drops back on each one. The kernel's own offset field is always 0 under chrony, which slews by frequency instead.",
   overrides=[dashed("max error","orange")])
ts("Clock Drift",[tgt("(node_timex_frequency_adjustment_ratio - 1) * 1e6","correction")],12,12,unit="ppm",calcs=["min","max","lastNotNull"],
   desc="How hard the kernel is speeding up (positive) or slowing down (negative) the clock to keep it on network time: the crystal's own drift, which moves with temperature. 10 ppm is ~0.9 s/day the clock would gain or lose without sync.")
y+=8

# ── CPU ──
row("CPU — Ryzen 7 7800X3D")
ts("Usage by Mode",[tgt('avg by (mode) (rate(node_cpu_seconds_total{mode!="idle"}[2m])) * 100',"{{mode}}")],0,8,unit="percent",min=0,max=100,fill=40,stack=True)
ts("Busiest Core vs Average",[tgt('max(1 - rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100',"busiest core"),tgt('avg(1 - rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100',"average")],8,8,unit="percent",min=0,max=100,
   desc="A busiest core near 100 % with a low average is a single-threaded bottleneck: more cores won't help, clocks will.")
ts("Temperature & Clock",[tgt(temp(CPU),"Tctl"),tgt(temp(CPU,"temp3"),"CCD"),tgt('max(node_cpu_scaling_frequency_hertz) / 1e9',"fastest core (GHz)")],16,8,unit="celsius",thresholds=[(89,"red")],
   overrides=[by_regex(".*GHz.*",unit="none",custom__axisPlacement="right",custom__fillOpacity=0,decimals=2)],desc="Tctl throttles at 89. Boost is ~5.0 GHz single core.")
y+=8
ts("Load Average",[tgt("node_load1","1m"),tgt("node_load5","5m"),tgt("node_load15","15m")],0,8,min=0,thresholds=[(16,"red")],fill=0,desc="16 threads: sustained load above 16 means work is queueing.")
ts("Package Power",[tgt(CPU_W,"package"),tgt('sum(rate(node_rapl_core_joules_total[1m]))',"cores")],8,8,unit="watt",min=0,
   desc="RAPL. The kernel makes energy_uj root-only; strata-exporter.nix chmods it at boot, and without that this panel is empty.")
ts("Context Switches & Interrupts",[tgt("rate(node_context_switches_total[2m])","context switches/s"),tgt("rate(node_intr_total[2m])","interrupts/s")],16,8,unit="short",fill=0)
y+=8

# ── GPU ──
row("GPU — RX 9070 XT")
ts("Temperatures",[tgt(temp(GPU,"temp2"),"hotspot"),tgt(temp(GPU,"temp1"),"edge"),tgt(temp(GPU,"temp3"),"memory")],0,8,unit="celsius",thresholds=[(110,"red")],fill=0,calcs=["max","lastNotNull"],
   desc="Hotspot limit is 110 °C. ~24 °C over edge during steady load, 30-33 °C for the seconds it draws its full cap.")
ts("Hotspot − Edge",[tgt(f'{temp(GPU,"temp2")} - ignoring(sensor) {temp(GPU,"temp1")}',"delta")],8,8,unit="celsius",thresholds=[(25,"orange"),(35,"red")],
   desc="A delta that is high at moderate power, or that climbs over weeks, is paste or mount. Short spikes during power bursts are thermal lag and normal.")
ts("Power vs Cap",[tgt(f'node_hwmon_power_average_watt{{chip="{GPU}"}}',"power"),tgt(f'node_hwmon_power_cap_watt{{chip="{GPU}"}}',"cap")],16,8,unit="watt",min=0,
   desc="The cap (297 W, set by LACT in hosts/orchid/hardware.nix; stock 330 W) is the only thermal lever: the fans are already at 100 % under sustained load.",overrides=[dashed("cap","red")])
y+=8
ts("Clocks",[tgt(f'node_hwmon_freq_freq_mhz{{chip="{GPU}",sensor="sclk"}} * 1e6',"core"),tgt(f'node_hwmon_freq_freq_mhz{{chip="{GPU}",sensor="mclk"}} * 1e6',"memory")],0,8,unit="hertz",fill=0)
ts("Fan Duty",[tgt(f'node_hwmon_pwm{{chip="{GPU}"}} / 255 * 100',"fan duty")],8,8,unit="percent",min=0,max=100,
   desc="Commanded duty, not a measured speed: this card's tach reads 0 RPM under amdgpu. Zero-RPM mode is on, so 0 at idle is expected.")
ts("Core Voltage",[tgt(f'node_hwmon_in_volts{{chip="{GPU}"}}',"voltage")],16,8,unit="volt",fill=0,desc="Stock: the offset is 0 mV since 2026-10-09 and stays there.")
y+=8

# ── Memory ──
row("Memory — 64 GB DDR5-6000")
ts("Where the RAM Goes",[tgt("clamp_min(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes - node_zfs_arc_size, 0)","programs"),tgt("node_zfs_arc_size","ZFS cache"),
   tgt("node_memory_Cached_bytes + node_memory_Buffers_bytes + node_memory_SReclaimable_bytes","page cache"),tgt("node_memory_MemFree_bytes","free")],0,12,unit="bytes",min=0,fill=40,stack=True,
   desc="Programs is what's actually claimed. The ZFS cache (ARC, capped at 16 GiB) and page cache are reclaimable, so a full stack is not memory pressure; the PSI panel above is the honest signal.",calcs=["mean","max","lastNotNull"])
ts("DIMM Temperatures",[tgt(temp(c),n) for c,n in DIMMS],12,6,unit="celsius",thresholds=[(60,"red")],fill=0)
ts("Swap Activity",[tgt("rate(node_vmstat_pswpin[2m])","in"),tgt("rate(node_vmstat_pswpout[2m])","out")],18,6,unit="short",min=0,desc="Pages per second. Brief blips are fine; sustained traffic means the working set doesn't fit.")
y+=8
ts("ZFS Cache Hit Ratio",[tgt("rate(node_zfs_arc_hits[5m]) / (rate(node_zfs_arc_hits[5m]) + rate(node_zfs_arc_misses[5m]))","hit ratio")],0,12,unit="percentunit",min=0,max=1,
   desc="Share of ZFS reads served from RAM. Low while something cold is read (a game load, a model) and high again after.")
ts("Major Page Faults",[tgt("rate(node_vmstat_pgmajfault[2m])","major faults/s")],12,12,unit="short",min=0,desc="Faults that had to read from disk. Spikes when programs start; a sustained rate is memory pressure.")
y+=8

# ── Storage ──
row("Storage — NVMe, ZFS on LUKS")
bar("Filesystem Usage",[tgt('100 - (node_filesystem_avail_bytes{mountpoint=~"/persist|/nix|/boot|/persist/home|/var/lib/vms|/var/lib/docker"} / node_filesystem_size_bytes * 100)',"{{mountpoint}}")],0,8,thresholds=[(80,"orange"),(90,"red")])
ts("Throughput",[tgt(f'rate(node_disk_read_bytes_total{{device="{d}"}}[2m])',f"{n} read") for d,n in [("nvme0n1","500 GB"),("nvme1n1","2 TB")]]
   +[tgt(f'rate(node_disk_written_bytes_total{{device="{d}"}}[2m])',f"{n} write") for d,n in [("nvme0n1","500 GB"),("nvme1n1","2 TB")]],8,8,unit="Bps",min=0)
ts("Temperatures",[tgt(temp(c),n) for c,n in SSDS],16,8,unit="celsius",thresholds=[(80,"red")],fill=0)
y+=8
ts("Busy Time",[tgt('rate(node_disk_io_time_seconds_total{device="nvme0n1"}[2m])',"500 GB"),tgt('rate(node_disk_io_time_seconds_total{device="nvme1n1"}[2m])',"2 TB")],0,12,unit="percentunit",min=0,max=1,
   desc="Share of time each drive had I/O in flight. NVMe handles many requests at once, so 100 % here is not saturation, but sustained 100 % with high pressure-stall IO is.")
ts("I/O by Dataset",[tgt('rate(node_zfs_zpool_dataset_nread{zpool="rpool"}[2m])',"read {{dataset}}"),tgt('rate(node_zfs_zpool_dataset_nwritten{zpool="rpool"}[2m])',"write {{dataset}}")],12,12,unit="Bps",min=0)
y+=8

# ── Room ──
row("Room")
ts("Temperature",[tgt(ROOM,"room"),tgt("max(govee_dew_point_celsius)","dew point")],0,12,unit="celsius",calcs=["min","max","mean","lastNotNull"],
   desc="A wall or window colder than the dew point gets condensation.")
ts("Humidity",[tgt("max(govee_humidity_percent)","relative"),tgt("max(govee_absolute_humidity_grams_per_cubic_meter)","absolute (g/m³)")],12,12,unit="percent",min=0,max=100,thresholds=[(60,"orange"),(70,"red")],calcs=["min","max","mean","lastNotNull"],
   desc="Absolute humidity doesn't move with temperature, so it shows whether airing actually removed moisture (right axis).",
   overrides=[by_regex("absolute.*",unit="none",min=0,max=30,custom__thresholdsStyle={"mode":"off"},custom__axisPlacement="right",custom__fillOpacity=0)])
y+=8

# ── Network ──
row("Network",collapsed=True)
ts("Throughput",[tgt('rate(node_network_receive_bytes_total{device="enp12s0"}[2m]) * 8',"LAN down"),tgt('rate(node_network_transmit_bytes_total{device="enp12s0"}[2m]) * 8',"LAN up"),
   tgt('rate(node_network_receive_bytes_total{device="tailscale0"}[2m]) * 8',"Tailscale down"),tgt('rate(node_network_transmit_bytes_total{device="tailscale0"}[2m]) * 8',"Tailscale up")],0,12,unit="bps",min=0)
ts("Errors & Drops",[tgt('sum(rate(node_network_receive_errs_total{device!="lo"}[2m]) + rate(node_network_receive_drop_total{device!="lo"}[2m]))',"receive"),tgt('sum(rate(node_network_transmit_errs_total{device!="lo"}[2m]) + rate(node_network_transmit_drop_total{device!="lo"}[2m]))',"transmit")],12,6,unit="short",min=0)
ts("TCP",[tgt("node_netstat_Tcp_CurrEstab","connections"),tgt("rate(node_netstat_Tcp_RetransSegs[2m])","retransmits/s")],18,6,unit="short",fill=0)
y+=8

# ── Services ──
row("Services",collapsed=True)
bar("Units by State",[tgt("count by(state) (node_systemd_unit_state == 1)","{{state}}")],0,8,unit="short",max=None)
add({"id":pid(),"type":"table","title":"Failed Units","datasource":DS,"gridPos":{"x":8,"y":y,"w":8,"h":8},
  "targets":[{"datasource":DS,"expr":'node_systemd_unit_state{state="failed"} == 1',"format":"table","instant":True,"refId":"A"}],
  "transformations":[{"id":"organize","options":{"excludeByName":{"Time":True,"Value":True,"__name__":True,"instance":True,"job":True,"state":True,"type":True},"indexByName":{}}}],
  "fieldConfig":{"defaults":{"noValue":"none"},"overrides":[]},"options":{}})
ts("Processes",[tgt("node_procs_running","running"),tgt("node_procs_blocked","waiting on IO")],16,8,unit="short",min=0,fill=0)
y+=8

# ── Strata ── (stopped since 2026-10-11; collapsed so its empty panels stay out of the way)
row("Strata — LLM server",collapsed=True)
stat("Model",'strata_info == 1',0,6,legend="{{model}}",spark=False,desc="Empty while the server is down.")
dest[0][-1]["options"]["textMode"]="name"
stat("Doing",'strata_live_state == 1',6,4,legend="{{phase}}",spark=False)
dest[0][-1]["options"]["textMode"]="name"
stat("Live t/s","strata_live_tokens_per_second",10,4,unit="short",decimals=0,desc="Generation rate over the last ~2 s; 0 while idle.")
stat("Context","strata_live_prompt_tokens",14,4,unit="short")
stat("Experts in VRAM","strata_engine_expert_slots",18,3,unit="short",desc="More cached experts = faster generation.")
stat("Up","strata_up",21,3,spark=False,base="red",mappings={1:("up","green"),0:("down","red")})
y+=4
ts("Generation Speed",[tgt("strata_live_tokens_per_second","live"),tgt("strata_live_tokens_per_second_mean","request mean"),tgt("strata_last_request_decode_tokens_per_second","last request")],0,8,unit="short",min=0,
   desc="tokens/s while generating. Live is a ~2 s window; request mean is since the request's first token; last request is the engine's own figure.")
ts("Throughput (1 m)",[tgt("rate(strata_output_tokens_total[1m])","generated, wall clock"),tgt("rate(strata_output_tokens_total[1m]) / rate(strata_decode_seconds_total[1m])","generated, while decoding"),
   tgt("(rate(strata_prompt_tokens_total[1m]) - rate(strata_prompt_reused_tokens_total[1m])) / rate(strata_prompt_seconds_total[1m])","prompt read, while prefilling")],8,8,unit="short",min=0)
ts("Energy per Generated Mtoken",[tgt(f'{WALL} / 3600 / 1000 * 1e6 / sum(rate(strata_output_tokens_total[1m])) and sum(rate(strata_output_tokens_total[1m])) > 5',"kWh / Mtoken")],16,8,unit="short",min=0,
   desc="Measured wall power divided by Strata's wall-clock generation rate over the last minute. Wall clock includes prefill and the idle gaps between an agent's turns. Only drawn while generating more than 5 t/s.")
y+=8
ts("Expert Cache & Draft",[tgt("strata_last_request_expert_cache_hit_rate","VRAM hit rate"),tgt("strata_last_request_pcie_share","read over PCIe"),tgt("strata_last_request_draft_accept_ratio","draft accepted")],0,8,unit="percentunit",min=0,max=1)
ts("Context & Reply Length",[tgt("strata_live_prompt_tokens","context"),tgt("strata_live_generated_tokens","generated this reply"),tgt("strata_last_request_output_tokens","last reply")],8,8,unit="short",min=0,
   desc="A reply that climbs to 16384 is one that hit the output cap (a thinking spiral).")
ts("Requests & Tokens",[tgt("rate(strata_requests_total[5m]) * 60","requests / min"),tgt("rate(strata_output_tokens_total[5m]) * 60","generated tokens / min")],16,8,unit="short",min=0)
y+=8

# ── Sensor health ── (the plug and the thermometer themselves, only needed when their data stops)
row("Sensor Health",collapsed=True)
stat("Power Meter","max(tapo_up)",0,4,spark=False,base="red",mappings={1:("online","green"),0:("offline","red")},noValue="no data",
     desc="Offline with 'Authentication failed' in `journalctl -u tapo-exporter` means /persist/secrets/tapo/credentials is wrong.")
stat("Power Meter Wi-Fi","max(tapo_wifi_rssi_dbm)",4,4,unit="dBm",decimals=0,base="red",thresholds=[(-75,"orange"),(-65,"green")])
stat("Thermometer Last Heard","time() - max(govee_last_seen_timestamp_seconds)",8,4,unit="s",decimals=0,thresholds=[(120,"orange"),(600,"red")],noValue="never",
     desc="Past 10 min the room readings drop out. Never heard: check `journalctl -u govee-exporter`, that it is in range, and that the phone app isn't connected to it (it stops advertising while it is).")
stat("Thermometer Battery","min(govee_battery_percent)",12,4,unit="percent",decimals=0,base="red",thresholds=[(15,"orange"),(30,"green")],desc="Two AAA cells.")
stat("Thermometer Signal","max(govee_rssi_dbm)",16,4,unit="dBm",decimals=0,base="red",thresholds=[(-90,"orange"),(-80,"green")])
stat("Inotify Watches","node_inotify_watches / node_inotify_max_user_watches * 100",20,4,unit="percent",decimals=1,thresholds=[(70,"orange"),(90,"red")])
y+=4

annotations=[
  {"builtIn":1,"datasource":{"type":"grafana","uid":"-- Grafana --"},"enable":True,"hide":True,"iconColor":"rgba(0, 211, 255, 1)","name":"Annotations & Alerts","type":"dashboard"},
  # The boot time itself is the annotation's timestamp, so the marker lands on
  # the boot even when the exporter came up minutes later (LUKS prompt).
  {"datasource":DS,"enable":True,"iconColor":"purple","name":"Boots","expr":"node_boot_time_seconds * 1000","useValueForTime":True,"step":"1m","titleFormat":"boot","textFormat":"system booted"},
  {"datasource":DS,"enable":True,"iconColor":"red","name":"Failed units","expr":'count(node_systemd_unit_state{state="failed"} == 1) > 0',"step":"1m","titleFormat":"failed units","textFormat":"{{value}} failed"},
]
dash={"uid":"orchid-overview","title":"Orchid — System Overview","tags":["orchid"],"timezone":"browser","schemaVersion":39,"refresh":"30s",
      "graphTooltip":1,"time":{"from":"now-6h","to":"now"},"templating":{"list":[]},"annotations":{"list":annotations},"editable":True,"panels":panels}
out="services/grafana/dashboards/orchid-overview.json"
json.dump(dash,open(out,"w"),indent=2); open(out,"a").write("\n")
print("panels:",sum(1+len(p.get("panels",[])) for p in panels),"rows:",sum(p["type"]=="row" for p in panels))
