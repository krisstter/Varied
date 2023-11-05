using System;
using System.Diagnostics;
using System.IO;
using log4net;
using log4net.Config;

class Program
{
    private static ILog logger = LogManager.GetLogger(typeof(Program));

    static void Main()
    {
        // Load log4net configuration from the XML file
        XmlConfigurator.Configure(new FileInfo("log4net.config"));

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

        string filePath = EngineJob.TradeLookUpFileName;

        try
        {
            lock (fileLock)
            {
                using (StreamWriter writer = new StreamWriter(filePath, true))
                {
                    writer.WriteLine(record);
                }
            }

            // Log a success message
            logger.Info("File appended successfully.");
        }
        catch (Exception ex)
        {
            // Log an error message with the exception details
            logger.Error($"Error appending to file: {ex.Message}", ex);
        }
    }
}
