using System.Diagnostics;
using API;
using Microsoft.EntityFrameworkCore;
using TestProject;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddHostedService<TimeTick>();
builder.Services.AddHostedService<ParallelQueryDb>();
//builder.Services.AddHostedService<SequentialQueryDB>();


var cnxString = CnxString();

builder.Services.AddDbContextFactory<MarketOrdersContext>(optionsBuilder => {
    optionsBuilder.UseNpgsql(cnxString)
        .EnableSensitiveDataLogging()
        .LogTo(Console.WriteLine);
}, ServiceLifetime.Singleton);

builder.Services.AddDbContext<MarketOrdersContext>(optionsBuilder => {
    optionsBuilder.UseNpgsql(cnxString)
        .EnableSensitiveDataLogging()
        .LogTo(s => Debug.WriteLine(s));
},
ServiceLifetime.Singleton);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

string CnxString()
{
    var provider = builder.Services.BuildServiceProvider();
    var config = provider.GetRequiredService<IConfiguration>();

    var pooling = bool.Parse(config["DbCnxPooling"]);
    var connectionString = pooling ? config.GetConnectionString("WithPooling") : config.GetConnectionString("WithoutPooling");
    return connectionString;
}