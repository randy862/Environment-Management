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
        }
    }

    Paths = @{
        ProxmoxCtl = '/home/debian/bin/proxmoxctl'
    }
}
