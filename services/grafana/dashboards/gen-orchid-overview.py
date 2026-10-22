import json
GPU='0000:02:00_0_0000:03:00_0'; IGPU='0000:00:08_1_0000:10:00_0'; CPU='pci0000:00_0000:00:18_3'
DS={"type":"prometheus","uid":"prometheus"}
panels=[]; y=0; nid=[0]
def pid(): nid[0]+=1; return nid[0]
def row(title):
    global y
    panels.append({"id":pid(),"type":"row","title":title,"collapsed":False,"gridPos":{"x":0,"y":y,"w":24,"h":1},"panels":[]}); y+=1
def tgt(expr,legend="",ref="A"): return {"datasource":DS,"expr":expr,"legendFormat":legend,"refId":ref}
def ts(title,targets,x,w,h=8,unit=None,desc=None,thresholds=None,min=None,max=None,fill=0,stack=False,overrides=None):
    fc={"defaults":{"custom":{"fillOpacity":fill,"lineWidth":1,"showPoints":"never"}},"overrides":overrides or []}
    if unit: fc["defaults"]["unit"]=unit
    if min is not None: fc["defaults"]["min"]=min
    if max is not None: fc["defaults"]["max"]=max
    if stack: fc["defaults"]["custom"]["stacking"]={"mode":"normal"}
    if thresholds:
        fc["defaults"]["custom"]["thresholdsStyle"]={"mode":"line"}
        fc["defaults"]["thresholds"]={"mode":"absolute","steps":[{"color":"green","value":None}]+[{"color":c,"value":v} for v,c in thresholds]}
    p={"id":pid(),"type":"timeseries","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
       "options":{"legend":{"displayMode":"list","placement":"bottom"},"tooltip":{"mode":"multi","sort":"desc"}},
       "targets":[dict(t,refId=chr(65+i)) for i,t in enumerate(targets)]}
    if desc: p["description"]=desc
    panels.append(p); return p
def stat(title,expr,x,w,h=4,unit=None,thresholds=None,decimals=None,desc=None,legend=""):
    fc={"defaults":{"thresholds":{"mode":"absolute","steps":[{"color":"green","value":None}]+[{"color":c,"value":v} for v,c in (thresholds or [])]}},"overrides":[]}
    if unit: fc["defaults"]["unit"]=unit
    if decimals is not None: fc["defaults"]["decimals"]=decimals
    p={"id":pid(),"type":"stat","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
       "options":{"colorMode":"value","graphMode":"area","reduceOptions":{"calcs":["lastNotNull"]},"textMode":"value"},"targets":[tgt(expr,legend)]}
    if desc: p["description"]=desc
    panels.append(p); return p
def bar(title,expr,legend,x,w,h=8,unit="percent",max=100,thresholds=None):
    fc={"defaults":{"unit":unit,"min":0,"max":max,"thresholds":{"mode":"absolute","steps":[{"color":"green","value":None}]+[{"color":c,"value":v} for v,c in (thresholds or [])]}},"overrides":[]}
    panels.append({"id":pid(),"type":"bargauge","title":title,"datasource":DS,"gridPos":{"x":x,"y":y,"w":w,"h":h},"fieldConfig":fc,
      "options":{"orientation":"horizontal","displayMode":"gradient","reduceOptions":{"calcs":["lastNotNull"]}},"targets":[tgt(expr,legend)]})
def temp(chip,sensor): return f'node_hwmon_temp_celsius{{chip="{chip}",sensor="{sensor}"}}'
def labelled(metric,chip,labels): return f'{metric}{{chip="{chip}"}} * on(chip,sensor) group_left(label) node_hwmon_sensor_label{{chip="{chip}",label=~"{labels}"}}'

# ── Overview ──
row("Overview")
stat("Uptime","node_time_seconds - node_boot_time_seconds",0,3,unit="s")
stat("CPU",'100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)',3,3,unit="percent",decimals=0,thresholds=[(70,"orange"),(90,"red")])
stat("Memory","(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",6,3,unit="percent",decimals=0,thresholds=[(80,"orange"),(92,"red")])
stat("Load (1m)","node_load1",9,3,decimals=1,thresholds=[(8,"orange"),(16,"red")])
stat("CPU Tctl",temp(CPU,"temp1"),12,3,unit="celsius",decimals=0,thresholds=[(80,"orange"),(89,"red")],desc="7800X3D Tctl. The chip throttles at 89 °C.")
stat("GPU Junction",temp(GPU,"temp2"),15,3,unit="celsius",decimals=0,thresholds=[(95,"orange"),(105,"red")],desc="9070 XT hotspot. Limit is 110 °C; sustained ~300 W compute sits at 90-105 with the fans already at 100 %.")
stat("GPU Power",f'node_hwmon_power_average_watt{{chip="{GPU}"}}',18,3,unit="watt",decimals=0,thresholds=[(280,"orange"),(320,"red")])
stat("Failed Units",'count(node_systemd_unit_state{state="failed"} == 1) or vector(0)',21,3,decimals=0,thresholds=[(1,"red")])
y+=4

# ── Wall power ──
row("Wall Power — Tapo P110 (hosts/orchid/system/tapo-exporter.nix)")
stat("Wall Power","tapo_power_watts",0,4,unit="watt",decimals=0,desc="Measured at the socket by the P110, polled every 5 s.")
stat("Today","tapo_energy_today_kwh",4,4,unit="kwatth",decimals=2,desc="The plug's own counter since local midnight.")
stat("This Month","tapo_energy_month_kwh",8,4,unit="kwatth",decimals=1,desc="The plug's own counter since the 1st.")
stat("Over Dashboard Range","avg_over_time(tapo_power_watts[$__range]) * $__range_s / 3600 / 1000",12,4,unit="kwatth",decimals=2,
     desc="Mean wall power over the selected time range × its length. Gaps where the plug didn't answer are left out of the mean, not counted as 0 W.")
stat("Plug Up","tapo_up",16,4,thresholds=[(1,"green")],desc="1 while the plug answers and accepts the login. 0 with 'Authentication failed' in `journalctl -u tapo-exporter` means /persist/secrets/tapo/credentials is wrong.")
stat("Plug Wi-Fi","tapo_wifi_rssi_dbm",20,4,unit="dBm",decimals=0)
y+=4
ts("Wall vs Measured Components",[tgt("tapo_power_watts","wall"),tgt(f'sum(node_hwmon_power_average_watt{{chip="{GPU}"}})',"GPU"),
   tgt('sum(rate(node_rapl_package_joules_total[1m]))',"CPU package"),
   tgt(f'sum(tapo_power_watts) - sum(node_hwmon_power_average_watt{{chip="{GPU}"}}) - sum(rate(node_rapl_package_joules_total[1m]))',"everything else")],0,16,unit="watt",min=0,
   desc="'Everything else' is the wall reading minus what the GPU and CPU report: board, DIMMs, NVMe, fans, the iGPU, PSU conversion loss, and anything else on the same plug. It is what the Strata row's energy panel guesses as +40 W and /0.9.")
ts("Energy Today",[tgt("tapo_energy_today_kwh","kWh since midnight")],16,8,unit="kwatth",min=0,fill=10)
y+=8

# ── Room ──
row("Room — Govee H5075 (hosts/orchid/system/govee-exporter.nix)")
stat("Temperature","govee_temperature_celsius",0,4,unit="celsius",decimals=1,legend="{{name}}",thresholds=[(26,"orange"),(30,"red")])
stat("Humidity","govee_humidity_percent",4,4,unit="percent",decimals=0,legend="{{name}}",thresholds=[(60,"orange"),(70,"red")],
     desc="40-60 % is the comfortable band; above 60 % for long stretches is where mould starts.")
stat("Dew Point","govee_dew_point_celsius",8,3,unit="celsius",decimals=1,legend="{{name}}",
     desc="Derived by the exporter (Magnus formula). A wall or window colder than this gets condensation.")
stat("Absolute Humidity","govee_absolute_humidity_grams_per_cubic_meter",11,3,unit="none",decimals=1,legend="{{name}}",
     desc="Water vapour in g/m³, derived by the exporter. Unlike relative humidity it doesn't move with temperature, so it shows whether airing actually removed moisture.")
batt=stat("Battery","govee_battery_percent",14,4,unit="percent",decimals=0,legend="{{name}}",desc="As the thermometer reports it. Two AAA cells.")
batt["fieldConfig"]["defaults"]["thresholds"]["steps"]=[{"color":"red","value":None},{"color":"orange","value":15},{"color":"green","value":30}]
stat("Signal","govee_rssi_dbm",18,3,unit="dBm",decimals=0,legend="{{name}}",desc="RSSI of the last advertisement orchid heard.")
stat("Last Heard","time() - max(govee_last_seen_timestamp_seconds)",21,3,unit="s",decimals=0,thresholds=[(120,"orange"),(600,"red")],
     desc="Seconds since any H5075 was heard. Past 10 min the readings drop out (stale, not frozen). No data at all means nothing has been heard since govee-exporter started: check `journalctl -u govee-exporter` that the thermometer is within range, and that the Govee phone app isn't connected to it (the H5075 stops advertising while it is).")
y+=4
for p in [ts("Temperature",[tgt("govee_temperature_celsius","{{name}}"),tgt("govee_dew_point_celsius","{{name}} dew point")],0,12,unit="celsius"),
          ts("Humidity",[tgt("govee_humidity_percent","{{name}} relative (%)")],12,12,unit="percent",min=0,max=100,thresholds=[(60,"orange"),(70,"red")])]:
    p["options"]["legend"]={"displayMode":"table","placement":"bottom","calcs":["min","max","mean","lastNotNull"]}
y+=8

# ── Stability ──
row("Stability (hang history)")
stat("Booted at","node_boot_time_seconds * 1000",0,4,unit="dateTimeAsIso",desc="A step here is a reboot; an unexplained one is a hang/reset. Cross-check with `journalctl --list-boots`.")
stat("OOM Kills","node_vmstat_oom_kill",4,3,decimals=0,thresholds=[(1,"red")])
stat("rpool Online",'node_zfs_zpool_state{zpool="rpool",state="online"}',7,3,decimals=0,thresholds=[(0,"red"),(1,"green")])
stat("System State","node_systemd_system_running",10,3,decimals=0,thresholds=[(0,"red"),(1,"green")])
ts("Pressure Stall (PSI)",[tgt("rate(node_pressure_cpu_waiting_seconds_total[2m])","CPU some"),tgt("rate(node_pressure_io_waiting_seconds_total[2m])","IO some"),tgt("rate(node_pressure_memory_waiting_seconds_total[2m])","memory some"),tgt("rate(node_pressure_memory_stalled_seconds_total[2m])","memory full")],13,11,h=8,unit="percentunit",min=0,
   desc="Share of wall time at least one task waited on the resource. Memory 'full' near 1 is swap death, the one software failure that looks like a hang.")
y+=8

# ── CPU ──
row("CPU — Ryzen 7 7800X3D")
ts("CPU Temperatures",[tgt(temp(CPU,"temp1"),"Tctl"),tgt(temp(CPU,"temp3"),"Tccd1")],0,8,unit="celsius",thresholds=[(80,"orange"),(89,"red")],
   desc="Tctl is the control temperature (throttle at 89); Tccd1 the die. Curve Optimizer is at zero since 2026-10-09 (hosts/orchid/hardware.nix).")
ts("Per-Core Frequency",[tgt("node_cpu_scaling_frequency_hertz","core {{cpu}}")],8,8,unit="hertz",desc="Governor is `performance` (floor 4.2 GHz); boost ~5.0-5.05 GHz single core.")
ts("Usage by Mode",[tgt('avg by (mode) (rate(node_cpu_seconds_total{mode!="idle"}[2m])) * 100',"{{mode}}")],16,8,unit="percent",min=0,max=100,fill=20,stack=True)
y+=8
ts("Per-Core Usage",[tgt('(1 - rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100',"core {{cpu}}")],0,12,unit="percent",min=0,max=100)
ts("Load Average",[tgt("node_load1","1m"),tgt("node_load5","5m"),tgt("node_load15","15m")],12,6,min=0,thresholds=[(16,"red")],desc="16 threads.")
ts("Context Switches & Interrupts",[tgt("rate(node_context_switches_total[2m])","ctx switches/s"),tgt("rate(node_intr_total[2m])","interrupts/s")],18,6,unit="short")
y+=8

# ── GPU ──
row("GPU — RX 9070 XT (03:00.0)")
ts("GPU Temperatures",[tgt(temp(GPU,"temp2"),"junction"),tgt(temp(GPU,"temp1"),"edge"),tgt(temp(GPU,"temp3"),"memory")],0,8,unit="celsius",thresholds=[(100,"orange"),(110,"red")],
   desc="Junction (hotspot) limit is 110 °C. Measured: ~24 °C over edge during steady generation, 30-33 °C for the seconds it draws its full cap.")
ts("Junction − Edge",[tgt(f'{temp(GPU,"temp2")} - ignoring(sensor) {temp(GPU,"temp1")}',"delta")],8,8,unit="celsius",thresholds=[(25,"orange"),(35,"red")],
   desc="A delta that is high at moderate power, or that climbs over weeks, is paste or mount. Short spikes during power bursts are thermal lag and normal.")
ts("Power & Cap",[tgt(f'node_hwmon_power_average_watt{{chip="{GPU}"}}',"PPT"),tgt(f'node_hwmon_power_cap_watt{{chip="{GPU}"}}',"cap")],16,8,unit="watt",min=0,
   desc="Cap is 297 W from LACT (hosts/orchid/hardware.nix); stock is 330 W. The cap is the only thermal lever: fans are already at 100 % under sustained load.",
   overrides=[{"matcher":{"id":"byName","options":"cap"},"properties":[{"id":"custom.lineStyle","value":{"fill":"dash","dash":[10,10]}},{"id":"color","value":{"mode":"fixed","fixedColor":"red"}}]}])
y+=8
ts("Fan Duty",[tgt(f'node_hwmon_pwm{{chip="{GPU}"}} / 255 * 100',"commanded PWM %")],0,8,unit="percent",min=0,max=100,
   desc="The commanded PWM duty, not a measured speed: this card's tach reads 0 RPM under amdgpu (VBIOS 113-R907XTGOL-F60), so fan1_input is useless. Zero-RPM mode is on, so 0 at idle is expected.")
ts("GPU Clocks",[tgt(f'node_hwmon_freq_freq_mhz{{chip="{GPU}",sensor="sclk"}}',"sclk"),tgt(f'node_hwmon_freq_freq_mhz{{chip="{GPU}",sensor="mclk"}}',"mclk")],8,8,unit="rotmhz" if False else "short",desc="MHz.")
ts("GPU Voltage",[tgt(f'node_hwmon_in_volts{{chip="{GPU}"}}',"vddgfx")],16,8,unit="volt",desc="Offset is 0 mV since 2026-10-09: -100 mV hung the MES/gfx queues under Strata compute three times on 2026-10-07.")
y+=8
ts("CPU Package Power (RAPL)",[tgt('rate(node_rapl_package_joules_total[1m])',"package"),tgt('rate(node_rapl_core_joules_total[1m])',"cores")],0,8,unit="watt",min=0,
   desc="Zen 4's RAPL counters via node-exporter. The kernel makes energy_uj root-only, so hosts/orchid/system/strata-exporter.nix chmods it at boot; without that this panel is empty. The iGPU's hwmon has no power sensor on this kernel, so it is not used.")
ts("Energy per Generated Mtoken",[tgt(f'(node_hwmon_power_average_watt{{chip="{GPU}"}} + ignoring(chip,sensor,index,path) rate(node_rapl_package_joules_total[1m]) + 40) / 0.9 / 3600 / 1000 * 1e6 / rate(strata_output_tokens_total[1m]) and rate(strata_output_tokens_total[1m]) > 5',"kWh / Mtoken")],8,8,unit="short",min=0,
   desc="(GPU W + CPU package W + 40 W for board, DIMMs, NVMe, fans) / 0.9 PSU efficiency, divided by Strata's wall-clock generation rate over the last minute. Wall clock includes prefill and the idle gaps between an agent's turns, so an agent session reads 3-4 kWh/Mtoken while pure generation is ~2 (IQ3_S) or ~1.8 (IQ2_XS). Only drawn while generating more than 5 t/s.")
y+=8

# ── Strata ──
row("Strata — LLM server (hosts/orchid/system/strata-exporter.nix)")
stat("Model",'strata_info == 1',0,6,legend="{{model}}",desc="From Strata's GET /metrics. Empty while the server is down.")
panels[-1]["options"]["textMode"]="name"; panels[-1]["options"]["graphMode"]="none"
stat("Doing",'strata_live_state == 1',6,4,legend="{{phase}}",desc="idle, reading the prompt, thinking, writing a tool call or an answer.")
panels[-1]["options"]["textMode"]="name"; panels[-1]["options"]["graphMode"]="none"
stat("Live t/s","strata_live_tokens_per_second",10,4,unit="short",decimals=0,desc="Generation rate over the last ~2 s; 0 while idle.")
stat("Context","strata_live_prompt_tokens",14,4,unit="short",desc="Tokens of context in the current request.")
stat("Experts in VRAM","strata_engine_expert_slots",18,3,unit="short",desc="More cached experts = faster generation. IQ3_S fits 4116 in 7.9 GB.")
stat("Up","strata_up",21,3,thresholds=[(1,"green")],desc="1 while the server answers /metrics.")
panels[-1]["fieldConfig"]["defaults"]["thresholds"]["steps"][0]["color"]="red"
y+=4
ts("Generation Speed",[tgt("strata_live_tokens_per_second","live"),tgt("strata_live_tokens_per_second_mean","request mean"),tgt("strata_last_request_decode_tokens_per_second","last request")],0,8,unit="short",min=0,
   desc="tokens/s while generating. Live is a ~2 s window; request mean is since the request's first token; last request is the engine's own figure for the request that just finished. Draft-assisted file writes run ~85 t/s, thinking ~55-60 (IQ2_XS) or ~50 (IQ3_S).")
ts("Throughput (1 m)",[tgt("rate(strata_output_tokens_total[1m])","generated, wall clock"),tgt("rate(strata_output_tokens_total[1m]) / rate(strata_decode_seconds_total[1m])","generated, while decoding"),
   tgt("(rate(strata_prompt_tokens_total[1m]) - rate(strata_prompt_reused_tokens_total[1m])) / rate(strata_prompt_seconds_total[1m])","prompt read, while prefilling")],8,8,unit="short",min=0,
   desc="From the server's running totals, so they survive restarts of the scrape. Wall-clock includes idle gaps between turns; the other two are the engine's rates during the work itself.")
ts("Prefill Speed",[tgt("strata_last_request_prefill_tokens_per_second","last request"),tgt("strata_live_prefill_tokens_per_second_mean","current request")],16,8,unit="short",min=0,
   desc="New prompt tokens read per second. ~1200 t/s cold; far higher when most of the prompt is reused from the KV cache (short reads amortise badly, so small numbers on tiny turns are normal).")
y+=8
ts("Expert Cache & Draft",[tgt("strata_last_request_expert_cache_hit_rate","VRAM hit rate"),tgt("strata_last_request_pcie_share","read over PCIe"),tgt("strata_last_request_draft_accept_ratio","draft accepted")],0,8,unit="percentunit",min=0,max=1,
   desc="Per request. Hit rate is the share of expert lookups served from the VRAM cache; the rest stream from RAM over PCIe. Draft acceptance is the MTP layer's success rate — ~85 % on code, lower on prose.")
ts("Context & Reply Length",[tgt("strata_live_prompt_tokens","context"),tgt("strata_live_generated_tokens","generated this reply"),tgt("strata_last_request_output_tokens","last reply")],8,8,unit="short",min=0,
   desc="A reply that climbs to 16384 is one that hit the output cap (a thinking spiral).")
ts("Requests & Tokens (rate)",[tgt("rate(strata_requests_total[5m]) * 60","requests / min"),tgt("rate(strata_output_tokens_total[5m]) * 60","generated tokens / min")],16,8,unit="short",min=0,
   desc="5-minute rates from the server's totals.")
y+=8

# ── Memory ──
row("Memory — 2×32 GB DDR5-6000 (EXPO)")
ts("DIMM Temperatures",[tgt('node_hwmon_temp_celsius{chip=~"i2c_.*"}',"{{chip}}")],0,8,unit="celsius",thresholds=[(60,"orange"),(70,"red")],
   desc="spd5118 on-DIMM sensors. Reached 66 °C during the 2026-10-07 Strata run and 72 °C in a passing 1 h stressapptest on 2026-10-09; EXPO at 6000 is clean to there.")
ts("Memory Usage",[tgt("node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes","used"),tgt("node_memory_Cached_bytes + node_memory_Buffers_bytes + node_memory_SReclaimable_bytes","cache + buffers"),tgt("node_zfs_arc_size","ZFS ARC"),tgt("node_memory_MemFree_bytes","free")],8,8,unit="bytes",min=0,fill=10,stack=True)
ts("Swap",[tgt("node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes","used"),tgt("rate(node_vmstat_pswpin[2m])","swap-in pages/s"),tgt("rate(node_vmstat_pswpout[2m])","swap-out pages/s")],16,8,unit="bytes",min=0,
   overrides=[{"matcher":{"id":"byRegexp","options":"swap-.*"},"properties":[{"id":"unit","value":"short"},{"id":"custom.axisPlacement","value":"right"}]}])
y+=8
ts("ZFS ARC",[tgt("node_zfs_arc_size","size"),tgt("node_zfs_arc_c","target (c)"),tgt("node_zfs_arc_c_max","max")],0,8,unit="bytes",min=0,desc="zfs_arc_max is 16 GiB on the kernel command line.")
ts("ARC Hit Ratio",[tgt("rate(node_zfs_arc_hits[5m]) / (rate(node_zfs_arc_hits[5m]) + rate(node_zfs_arc_misses[5m]))","hit ratio")],8,8,unit="percentunit",min=0,max=1)
ts("Page Faults",[tgt("rate(node_vmstat_pgfault[2m])","total/s"),tgt("rate(node_vmstat_pgmajfault[2m])","major/s")],16,8,unit="short")
y+=8

# ── Storage ──
row("Storage — NVMe + ZFS on LUKS")
ts("NVMe Temperatures",[tgt(labelled("node_hwmon_temp_celsius","nvme_nvme0","Composite|Sensor.*"),"nvme0 {{label}}"),tgt(labelled("node_hwmon_temp_celsius","nvme_nvme1","Composite|Sensor.*"),"nvme1 {{label}}")],0,8,unit="celsius",thresholds=[(70,"orange"),(80,"red")])
ts("Disk Throughput",[tgt('rate(node_disk_read_bytes_total{device=~"nvme[01]n1"}[2m])',"read {{device}}"),tgt('rate(node_disk_written_bytes_total{device=~"nvme[01]n1"}[2m])',"write {{device}}")],8,8,unit="Bps",min=0)
ts("Disk Utilization",[tgt('rate(node_disk_io_time_seconds_total{device=~"nvme[01]n1"}[2m])',"{{device}}")],16,8,unit="percentunit",min=0,max=1)
y+=8
bar("Filesystem Usage",'100 - (node_filesystem_avail_bytes{mountpoint=~"/persist|/nix|/boot|/persist/home|/var/lib/vms|/var/lib/docker"} / node_filesystem_size_bytes{mountpoint=~"/persist|/nix|/boot|/persist/home|/var/lib/vms|/var/lib/docker"} * 100)',"{{mountpoint}}",0,12,thresholds=[(80,"orange"),(90,"red")])
ts("rpool Dataset I/O",[tgt('rate(node_zfs_zpool_dataset_nread{zpool="rpool"}[2m])',"read {{dataset}}"),tgt('rate(node_zfs_zpool_dataset_nwritten{zpool="rpool"}[2m])',"write {{dataset}}")],12,12,unit="Bps",min=0)
y+=8

# ── Network ──
row("Network")
ts("Throughput",[tgt('rate(node_network_receive_bytes_total{device=~"enp12s0|tailscale0"}[2m]) * 8',"down {{device}}"),tgt('rate(node_network_transmit_bytes_total{device=~"enp12s0|tailscale0"}[2m]) * 8',"up {{device}}")],0,12,unit="bps",min=0)
ts("Errors & Drops",[tgt('rate(node_network_receive_errs_total{device!="lo"}[2m]) + rate(node_network_receive_drop_total{device!="lo"}[2m])',"rx {{device}}"),tgt('rate(node_network_transmit_errs_total{device!="lo"}[2m]) + rate(node_network_transmit_drop_total{device!="lo"}[2m])',"tx {{device}}")],12,6,unit="short",min=0)
ts("TCP",[tgt("node_netstat_Tcp_CurrEstab","established"),tgt("rate(node_netstat_Tcp_RetransSegs[2m])","retrans/s")],18,6,unit="short")
y+=8

# ── Services ──
row("Services")
bar("systemd Units by State","count by(state) (node_systemd_unit_state == 1)","{{state}}",0,8,unit="short",max=None)
panels.append({"id":pid(),"type":"table","title":"Failed Units","datasource":DS,"gridPos":{"x":8,"y":y,"w":8,"h":8},
  "targets":[{"datasource":DS,"expr":'node_systemd_unit_state{state="failed"} == 1',"format":"table","instant":True,"refId":"A"}],
  "transformations":[{"id":"organize","options":{"excludeByName":{"Time":True,"Value":True,"__name__":True,"instance":True,"job":True,"state":True,"type":True},"indexByName":{}}}],"fieldConfig":{"defaults":{},"overrides":[]},"options":{}})
ts("Processes",[tgt("node_procs_running","running"),tgt("node_procs_blocked","blocked on IO")],16,8,unit="short",min=0)
y+=8

dash={"uid":"orchid-overview","title":"Orchid — System Overview","tags":["orchid"],"timezone":"browser","schemaVersion":39,"refresh":"30s",
      "time":{"from":"now-3h","to":"now"},"templating":{"list":[]},"annotations":{"list":[]},"editable":True,"panels":panels}
# bargauge max=None cleanup
for p in panels:
    d=p.get("fieldConfig",{}).get("defaults",{})
    if d.get("max",0) is None: del d["max"]
out="services/grafana/dashboards/orchid-overview.json"
json.dump(dash,open(out,"w"),indent=2); open(out,"a").write("\n")
print("panels:",len(panels),"rows:",sum(p["type"]=="row" for p in panels),"height:",y)
