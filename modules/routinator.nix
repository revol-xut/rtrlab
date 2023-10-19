{ pkgs, config, lib, ... }:
let
  http-host = "127.0.0.1";
  http-port = 8323;
  rtr-host = "0.0.0.0";
  rtr-port = 3323;

  routinator-config-file = pkgs.writeText "routinator.conf" ''
    repository-dir = "/var/lib/routinator/rpki-cache/repository"
    exceptions = []
    strict = false
    stale = "reject"
    unsafe-vrps = "accept"
    unknown-objects = "warn"
    allow-dubious-hosts = false
    disable-rsync = false
    rsync-command = "${pkgs.rsync}/bin/rsync"
    rsync-timeout = 300
    disable-rrdp = false
    rrdp-fallback = "stale"
    rrdp-fallback-time = 3600
    rrdp-max-delta-count = 100
    rrdp-timeout = 300
    rrdp-tcp-keepalive = 60
    rrdp-root-certs = []
    rrdp-proxies = []
    max-object-size = 20000000
    max-ca-depth = 32
    enable-bgpsec = false
    dirty = false
    validation-threads = 16
    refresh = 600
    retry = 600
    expire = 7200
    history-size = 10
    systemd-listen = false
    rtr-tcp-keepalive = 60
    rtr-client-metrics = false
    log-level = "WARN"
    log = "default"
    syslog-facility = "daemon"
    rtr-tls-listen = []
    rtr-listen = ["${rtr-host}:${toString rtr-port}"]
    http-tls-listen = []
    http-listen = ["${http-host}:${toString http-port}"]
  '';

in
{

  nixpkgs.overlays = [
    (final: prev: {
      routinator = prev.routinator.overrideAttrs (old: {
        buildFeatures = [ "socks" "aspa" ];
      });
    })
  ];


  systemd.services = {
    "routinator" = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      script = ''
        ${pkgs.routinator}/bin/routinator --config ${routinator-config-file} --extra-tals-dir="/var/lib/routinator/tals" server
      '';

      serviceConfig = {
        Type = "forking";
        User = "routinator";
        Restart = "always";
      };
    };
    "krill" = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      script = ''
        ${pkgs.krill}/bin/krill --config /var/lib/krill/krill.conf
      '';

      serviceConfig = {
        Type = "forking";
        User = "krill";
        Restart = "always";
      };
    };
  };

  services = {
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "${config.rtrlab.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = "http://${http-host}:${toString http-port}/";
            };
          };
        };
      };
    };
  };

  users.users."routinator" = {
    name = "routinator";
    isSystemUser = true;
    uid = 1501;
    group = "routinator";
  };
  users.groups."routinator" = {
    name = "routinator";
    gid = 1502;
  };

  users.users."krill" = {
    name = "routinator";
    isSystemUser = true;
    uid = 1503;
    group = "krill";
  };
  users.groups."krill" = {
    name = "krill";
    gid = 1504;
  };
}
