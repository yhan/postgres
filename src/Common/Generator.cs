using Microsoft.Extensions.Configuration;
// using Index = blazor_pivottable.Pages.Index;

namespace Common;

public class Generator
{
    private static string[] topLevelStrategyOptions = { "VWAP", "TWAP", "WVOL", "ECLIPSE" };
    private static string[] strategyOptions = { "Hit", "Sweep", "Peg", "Fixing" };
    private static Random rand = new();
    private static string[] wayOptions = { "Buy", "Sell" };
    private static string[] instanceOptions = { "vm-1", "vm-paris", "vm-london", "vm-hongkong" };
    private static string[] venueOptions = { "ChiX", "ENX", "ENA-main", "GER-main" };
    private static string[] counterpartyOptions = { "cli-a", "cli-b", "cli-c" };
    private readonly int size;
    private readonly List<string> idBuffer;

    public Generator(IConfiguration config)
    {
        this.size = int.Parse(config["dataSize"]);
        idBuffer = new List<string>();
        for (int i = 0; i < size; i++)
        {
            idBuffer.Add(Guid.NewGuid().ToString());
        }
    }
    
    public List<MarketOrderVm> Execute()
    {
        var collection = new List<MarketOrderVm>();
        for (int i = 0; i < size; i++)
        {
            double coef = (double) i / size;
            
            var id = i%7==0 ? Guid.NewGuid().ToString(): idBuffer[i];
            collection.Add(new MarketOrderVm(
                id,
                Select<string>(topLevelStrategyOptions),
                Select(strategyOptions),
                Select(wayOptions),
                execNom: Math.Round(rand.NextDouble() * 1_000_000, MidpointRounding.ToZero) * coef,
                Select(instanceOptions),
                Select(counterpartyOptions),
                Select(Enum.GetValues<InstrumentType>()),
                Select(Enum.GetValues<VenueCategory>()),
                Select(venueOptions),
                Select(Enum.GetValues<VenueType>()),
                RandomDateTimeOffset()));
        }

        return collection;
    }
    private DateTimeOffset RandomDateTimeOffset()
    {
        return DateTimeOffset.UtcNow.AddSeconds(-Math.Round(rand.NextDouble() * 1_000_000, MidpointRounding.ToZero));
    }

    private static T Select<T>(T[] array)
    {
        return array[rand.Next(0, array.Length)];
    }
}

public enum InstrumentType
{
    Equity,
    Future,
    FutureSpread
}

public enum VenueCategory
{
    LIT,
    DARK,
    DAR_AUCTION
}

public enum VenueType
{
    Main,
    Secondary,
    InternalMarket,
    DarkPool
}