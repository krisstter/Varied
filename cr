int maxRetries = 3;  // Define the maximum number of retry attempts
int retryDelayMilliseconds = 1000;  // Define the delay between retries in milliseconds

for (int retryCount = 0; retryCount < maxRetries; retryCount++)
{
    try
    {
        string header = "WU Key,TradeType,Number of Trades,Hash Code,Model Name,WU Creation Time (Relative),WU Creation Time (Absolute),Trade List";
        File.AppendAllText(TradeLookUpFileName, $"{header}{Environment.NewLine}");
        Log.Info($"Created work unit details file at {TradeLookUpFileName}");
        
        // If the file was saved successfully, break out of the loop
        break;
    }
    catch (Exception ex)
    {
        Log.Error($"Error while creating work unit details file: {ex.Message}");
        
        // If this was the last retry attempt, you can choose to handle the error or throw an exception
        if (retryCount == maxRetries - 1)
        {
            Log.Error("Failed to save the file after multiple retries.");
            // Handle the error or throw an exception as needed.
        }
        
        // Delay before the next retry
        Thread.Sleep(retryDelayMilliseconds);
    }
}
