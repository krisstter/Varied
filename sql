# Define the connection parameters
$serverName = "your_server_name"
$databaseName = "your_database_name"
$username = "your_username" # Use only if SQL Server authentication is required
$password = "your_password" # Use only if SQL Server authentication is required

# Construct the connection string
# Use Trusted_Connection=True for Windows Authentication, otherwise use User ID and Password
$connectionString = "Server=$serverName;Database=$databaseName;"

if ($username -and $password) {
    $connectionString += "User ID=$username;Password=$password;"
} else {
    $connectionString += "Trusted_Connection=True;"
}

# SQL Query to execute
$query = "SELECT TOP 10 * FROM your_table_name"

# Execute the SQL command
try {
    $results = Invoke-Sqlcmd -ConnectionString $connectionString -Query $query
    $results | Format-Table
} catch {
    Write-Error "An error occurred: $_"
}
