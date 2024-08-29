# Load the Oracle Managed Data Access assembly
Add-Type -Path "C:\path\to\Oracle.ManagedDataAccess.dll"

# Set Oracle environment variables
$env:ORACLE_HOME = "C:\path\to\oracle\client"
$env:TNS_ADMIN = "C:\path\to\oracle\config"
$env:NLS_LANG = "AMERICAN_AMERICA.UTF8"

# Parse script arguments
param(
    [string]$force_run = "NO"
)

if ($args.Count -ne 0 -and $args.Count -ne 2) {
    Write-Error "Usage: script.ps1 [-force_run yes/no]"
    exit 1
}

if ($args.Count -eq 2) {
    if ($args[0] -eq "-force_run") {
        $force_run = $args[1]
    } else {
        Write-Error "Usage: script.ps1 [-force_run yes/no]"
        exit 1
    }
}

$connectionString = "User Id=laredo_app;Password=laredo_appsp3!;Data Source=DFRSKC1C_C.world"
$conn = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($connectionString)

try {
    $conn.Open()

    # Check if staging is populated after last recon
    if ($force_run.ToUpper() -ne "YES") {
        $query = "SELECT STAGE_POPULATE_EDDT, RECON_READ_EDDT, CASE WHEN STAGE_POPULATE_EDDT > RECON_READ_EDDT THEN 1 ELSE 0 END FROM T_LAREDO_RECON_STATUS"
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $reader = $cmd.ExecuteReader()
        $reader.Read()
        $result = $reader.GetInt32(2)
        $last_stage_dt = $reader.GetString(0)
        $last_transfer_dt = $reader.GetString(1)
        $reader.Close()

        if ($result -eq 0) {
            Write-Output "There is no data staged from Laredo since last recon hence not doing any recon: $(Get-Date)"
            Write-Output "Last Stage time is: $last_stage_dt, last recon time is: $last_transfer_dt"
            exit 1
        }
    }

    Write-Output "Starting loading of the main table from stage table: $(Get-Date)"
    $cmd.CommandText = "BEGIN Pkg_laredo_recon.load_data_main(:r_count); END;"
    $param = New-Object Oracle.ManagedDataAccess.Client.OracleParameter("r_count", [System.Data.ParameterDirection]::Output)
    $param.OracleDbType = [Oracle.ManagedDataAccess.Client.OracleDbType]::Int32
    $cmd.Parameters.Add($param)
    $cmd.ExecuteNonQuery()
    $r_count = $param.Value
    Write-Output "Number of rows processed: $r_count"

    # Get differences between Laredo and t_cache_external
    Write-Output "Getting the differences between Laredo and t_cache_external: $(Get-Date)"
    $query = @"
        SELECT deal_id, version_num, obs_id, created_dtm, structure_type_name, snapshot_ver, risk_class_name
        FROM (
            SELECT deal_id, version_num, l.obs_id, l.created_dtm, l.structure_type_name, snapshot_ver, l.risk_class_name,
                   ROW_NUMBER() OVER (PARTITION BY l.deal_id ORDER BY l.version_num DESC) rn
            FROM t_laredo_main_deal l
            WHERE l.snapshot_ver = (SELECT SNAPSHOT_VER FROM T_LAREDO_RECON_STATUS)
              AND l.structure_type_name IN ('Unfunded CDS', 'Standalone Fee')
              AND l.ticket_type_cd = 'T'
        ) in_qry
        WHERE rn = 1
          AND NOT EXISTS (
              SELECT 1
              FROM credit_dbo.tcache_external t
              WHERE t.deal_id = in_qry.deal_id
                AND t.source_version = in_qry.version_num
                AND t.part_key = 1
                AND t.domain = 'Laredo'
          )
"@
    $cmd.CommandText = $query
    $reader = $cmd.ExecuteReader()

    $today = (Get-Date -Format "yyyyMMdd")
    $attfile = "CSV/frisk_laredo_recon_$today.csv"
    $fileContent = "Deal id,Version,Ticket,Create Date,Ticket Type,Snapshot version,Risk Class Name`n"
    $count = 0

    while ($reader.Read()) {
        $fileContent += "$($reader.GetString(0)), $($reader.GetString(1)), $($reader.GetString(2)), $($reader.GetString(3)), $($reader.GetString(4)), $($reader.GetString(5)), $($reader.GetString(6))`n"
        $count++
    }
    $reader.Close()
    $fileContent | Out-File -FilePath $attfile -Encoding utf8

    $mail_msg = "Attached is the list of deals that seem to be missing in Frisk from Laredo and also the discrepancy between tables tcache_external and tcache!`n`n"
    $mail_msg += "Total number of deal versions missing in fRisk from Laredo: $count`n`n"

    # Get discrepancies between tcache and tcache_external
    Write-Output "Getting the differences between tcache and t_cache_external: $(Get-Date)"
    $query = @"
        SELECT l.deal_id, l.version_num, l.obs_id, l.created_dtm, l.structure_type_name, l.snapshot_ver, l.risk_class_name
        FROM t_laredo_main_deal l, credit_dbo.tcache_external t
        WHERE t.deal_id = l.deal_id
          AND l.version_num = t.SOURCE_VERSION
          AND l.snapshot_ver = (SELECT SNAPSHOT_VER FROM T_LAREDO_RECON_STATUS)
          AND l.structure_type_name IN ('Unfunded CDS', 'Standalone Fee')
          AND l.ticket_type_cd = 'T'
          AND t.part_key = 1
          AND t.domain = 'Laredo'
        MINUS
        SELECT l.deal_id, l.version_num, l.obs_id, l.created_dtm, l.structure_type_name, l.snapshot_ver, l.risk_class_name
        FROM t_laredo_main_deal l, credit_dbo.tcache t
        WHERE t.deal_id = l.deal_id
          AND l.version_num = t.SOURCE_VERSION
          AND l.snapshot_ver = (SELECT SNAPSHOT_VER FROM T_LAREDO_RECON_STATUS)
          AND l.structure_type_name IN ('Unfunded CDS', 'Standalone Fee')
          AND l.ticket_type_cd = 'T'
          AND t.domain = 'Laredo'
"@
    $cmd.CommandText = $query
    $reader = $cmd.ExecuteReader()

    $attfile1 = "CSV/frisk_internal_recon_$today.csv"
    $fileContent1 = "Deal id,Version,Ticket,Create Date,Ticket Type,Snapshot version,Risk Class Name`n"
    $count = 0

    while ($reader.Read()) {
        $fileContent1 += "$($reader.GetString(0)), $($reader.GetString(1)), $($reader.GetString(2)), $($reader.GetString(3)), $($reader.GetString(4)), $($reader.GetString(5)), $($reader.GetString(6))`n"
        $count++
    }
    $reader.Close()
    $fileContent1 | Out-File -FilePath $attfile1 -Encoding utf8

    $mail_msg += "Total number of deal versions missing in tcache that are in tcache_external: $count`n`n"
    $mail_msg += "Please refer to Laredo GSD to get messages replayed: $attfile`n"

    # Send email
    $smtpServer = "smtp.ubs.com"
    $smtpFrom = "dl-frisk-support@ubs.com"
    $smtpTo = "DL-FRISK-LAREDO-RECON@ubs.com"
    $messageSubject = "Laredo reconciliation messages for $(Get-Date)"
    $messageBody = $mail_msg

    $message = New-Object system.net.mail.mailmessage
    $message.From = $smtpFrom
    $message.To.Add($smtpTo)
    $message.Subject = $messageSubject
    $message.Body = $messageBody

    $attachment = New-Object System.Net.Mail.Attachment($attfile)
    $message.Attachments.Add($attachment)
    $attachment1 = New-Object System.Net.Mail.Attachment($attfile1)
    $message.Attachments.Add($attachment1)

    $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($message)

    Write-Output "Recon is completed: $(Get-Date)"

} catch {
    Write-Error $_.Exception.Message
} finally {
    if ($conn -ne $null) {
        $conn.Close()
        $conn.Dispose()
    }
}
