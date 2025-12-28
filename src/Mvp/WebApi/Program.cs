using api.Settings;
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);

var mongoSettings = builder.Configuration.GetSection("MongoDb").Get<MyMongoDbSettings>()
    ?? throw new InvalidOperationException("MongoDb settings are missing.");
if (string.IsNullOrWhiteSpace(mongoSettings.ConnectionString) ||
    string.IsNullOrWhiteSpace(mongoSettings.DatabaseName))
{
    throw new InvalidOperationException("MongoDb ConnectionString and DatabaseName are required.");
}

builder.Services.AddSingleton<IMyMongoDbSettings>(mongoSettings);
builder.Services.AddSingleton<IMongoClient>(_ => new MongoClient(mongoSettings.ConnectionString));
builder.Services.AddSingleton<IMongoCollection<EchoRequest>>(sp =>
{
    var client = sp.GetRequiredService<IMongoClient>();
    var settings = sp.GetRequiredService<IMyMongoDbSettings>();
    var database = client.GetDatabase(settings.DatabaseName);
    return database.GetCollection<EchoRequest>("echos");
});

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(
        options =>
        {
            options.SwaggerEndpoint("/openapi/v1.json", "Ca.WebApi");
        }
    );
}

app.MapPost("/api/echo", async (EchoRequest request, IMongoCollection<EchoRequest> collection) =>
{
    await collection.InsertOneAsync(request);
    return Results.Ok($"Hello, {request.Name}");
});

app.UseHttpsRedirection();

app.Run();

record EchoRequest(string Name);
