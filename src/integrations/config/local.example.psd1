@{
    Hosts = @{
        Command001 = @{
            Address = '192.168.1.110'
            User = 'root'
        }
        App001 = @{
            Address = '192.168.1.200'
            User = 'debian'
        }
        Dns001 = @{
            Address = '192.168.1.203'
            User = 'debian'
        }
        Sql001 = @{
            Address = '192.168.1.202'
            User = 'debian'
        }
        Gateway001 = @{
            Address = '192.168.1.1'
            Scheme = 'https'
            ApiBasePath = '/proxy/network/integration'
            Site = 'default'
        }
    }

    Paths = @{
        ProxmoxCtl = '/home/debian/bin/proxmoxctl'
    }

    UniFi = @{
        ApiKeyEnvVar = 'UNIFI_API_KEY'
        VerifyTls = $false
    }

    Monitoring = @{
        DnsNames = @(
            'mitchell.school.local'
            'web001.school.local'
        )
        WebHealthUrl = 'http://192.168.1.210/health'
        WebControlUrl = 'http://192.168.1.210/control/'
        DatabasePort = 5432
        DnsPort = 53
    }

    Backups = @{
        Postgres = @{
            TargetRoot = 'X:\SQLBackup'
            RetentionDays = 14
            CompressionLevel = 6
            KeepDatabases = @()
        }
    }
}
