using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;
using Roblox.Web.Infrastructure;
using Roblox.Web.Infrastructure.Extensions;
using Roblox.Web.Infrastructure.Http;
using Roblox.Web.Infrastructure.Middleware;

namespace Roblox.ServiceDefaults;

public static class RobloxServiceDefaultsExtensions
{
    public static WebApplicationBuilder AddRobloxServiceDefaults(
        this WebApplicationBuilder builder,
        string serviceName,
        ServiceExposure exposure,
        Action<SwaggerGenOptions>? configureSwagger = null)
    {
        RobloxServiceInfrastructure.Initialize(builder.Configuration);
        builder.Services.AddRobloxWebInfrastructure(builder.Configuration);
        builder.Services.AddRobloxTelemetry(builder.Configuration, serviceName, builder.Environment.EnvironmentName);

        // Antiforgery tokens (and later cookies) are protected with the DataProtection
        // key ring. By default that ring is ephemeral: a new key is generated per
        // process, so a restart orphans every outstanding token and decrypting one
        // logs "The key {..} was not found in the key ring". Persist the ring to a
        // shared directory and give it one application name so all services use the
        // same keys across restarts.
        builder.Services.AddVedoraDataProtection(builder.Configuration);

        builder.Services.AddExceptionHandler<RobloxServiceExceptionHandler>();
        builder.Services.AddProblemDetails();
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = serviceName,
                Version = "v1",
            });
            configureSwagger?.Invoke(options);
        });
        builder.Services
            .AddHealthChecks()
            .AddCheck<RobloxInfrastructureHealthCheck>("dependencies", tags: new[] { "ready" });

        return builder;
    }

    public static async Task<WebApplication> UseRobloxServiceDefaults(this WebApplication app, ServiceExposure exposure)
    {
        Roblox.Services.ServiceProvider.Initialize(app.Services);
        app.UseRouting();
        app.UseRobloxRequestServicesScope();
        app.UseExceptionHandler();

        // Every service builds a request context and hashes the caller IP: internal
        // services through ProxyForwardedAuthMiddleware, the api proxy through
        // ApiProxyForwardedAuthMiddleware. The hasher needs its Redis-backed setup
        // loaded first, so initialize it here instead of relying on each Program.cs.
        await RobloxIpHasher.InitializeIpHashSetupAsync();

        if (exposure == ServiceExposure.InternalService)
        {
            app.UseMiddleware<ProxyForwardedAuthMiddleware>();
        }
        else if (exposure == ServiceExposure.PublicService)
        {
            app.UseMiddleware<ApiProxyForwardedAuthMiddleware>();
        }

        app.UseMiddleware<RobloxCsrfMiddleware>();

        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate = _ => false,
        });
        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = registration => registration.Tags.Contains("ready"),
        });

        return app;
    }
}
