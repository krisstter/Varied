string uniqueKey = "yourUniqueKey";
string modelName = "yourModelName";
double elapsedTime = 123.45; // Replace with the actual value
string tradeList = "yourTradeList";

string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
string record = String.Format("{0},{1},{2},{3},{4},{5},{6}",
    uniqueKey.Replace(',', '.'),
    uniqueKey,
    modelName,
    elapsedTime,
    timestamp,
    tradeList,
    Environment.NewLine);

// Specify the file path
string filePath = EngineJob.TradeLookUpFileName;

// Create a StreamWriter for appending to the file
using (StreamWriter writer = new StreamWriter(filePath, true))
{
    writer.WriteLine(record);
}
