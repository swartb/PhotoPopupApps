// PhotoReceiver.cs
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;

namespace PhotoPopupReceiver
{
    public sealed class PhotoReceiver : IAsyncDisposable
    {
        private IHost? _host;

        public async Task StartAsync(AppSettings settings, Func<string, Task> onPhotoSaved)
        {
            if (_host is not null)
                return;

            if (settings is null) throw new ArgumentNullException(nameof(settings));
            if (onPhotoSaved is null) throw new ArgumentNullException(nameof(onPhotoSaved));

            Directory.CreateDirectory(settings.SaveFolder);

            _host = Host.CreateDefaultBuilder()
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder
                        .UseKestrel()
                        .UseUrls($"http://0.0.0.0:{settings.Port}")
                        .Configure(app =>
                        {
                            app.UseRouting();
                            app.UseEndpoints(endpoints =>
                            {
                                endpoints.MapPost("/push-photo", async context =>
                                {
                                    if (!IsAuthorized(context, settings, out var failureStatus, out var failureMessage))
                                    {
                                        context.Response.StatusCode = failureStatus;
                                        context.Response.ContentType = "text/plain; charset=utf-8";
                                        await context.Response.WriteAsync(failureMessage);
                                        return;
                                    }

                                    if (!context.Request.HasFormContentType)
                                    {
                                        context.Response.StatusCode = StatusCodes.Status400BadRequest;
                                        await context.Response.WriteAsync("multipart/form-data expected");
                                        return;
                                    }

                                    var form = await context.Request.ReadFormAsync(context.RequestAborted);
                                    var file = form.Files.GetFile("file");
                                    if (file is null || file.Length == 0)
                                    {
                                        context.Response.StatusCode = StatusCodes.Status400BadRequest;
                                        await context.Response.WriteAsync("file missing");
                                        return;
                                    }

                                    var dayFolder = Path.Combine(settings.SaveFolder, DateTime.Now.ToString("yyyy-MM-dd"));
                                    Directory.CreateDirectory(dayFolder);

                                    var ext = Path.GetExtension(file.FileName);
                                    if (string.IsNullOrWhiteSpace(ext)) ext = ".jpg";

                                    var fileName = $"{DateTime.Now:HH-mm-ss_fff}_{Guid.NewGuid():N}{ext}";
                                    var savePath = Path.Combine(dayFolder, fileName);

                                    await using (var fs = File.Create(savePath))
                                    {
                                        await file.CopyToAsync(fs, context.RequestAborted);
                                    }

                                    await onPhotoSaved(savePath);

                                    context.Response.StatusCode = StatusCodes.Status200OK;
                                    await context.Response.WriteAsync("ok");
                                });
                            });
                        });
                })
                .Build();

            await _host.StartAsync();
        }

        private static bool IsAuthorized(HttpContext context, AppSettings settings, out int failureStatus, out string failureMessage)
        {
            var token = context.Request.Query["token"].FirstOrDefault() ?? string.Empty;
            if (!string.Equals(token, settings.Token, StringComparison.Ordinal))
            {
                failureStatus = StatusCodes.Status401Unauthorized;
                failureMessage = "Unauthorized: invalid token.";
                return false;
            }

            if (!settings.RequirePassword)
            {
                failureStatus = 0;
                failureMessage = string.Empty;
                return true;
            }

            var expected = (settings.Password ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(expected))
            {
                failureStatus = StatusCodes.Status401Unauthorized;
                failureMessage = "Unauthorized: password required but not configured.";
                return false;
            }

            var provided = (context.Request.Headers["X-Auth"].FirstOrDefault() ?? context.Request.Headers["X-Auth-Token"].FirstOrDefault() ?? string.Empty).Trim();
            if (!string.Equals(provided, expected, StringComparison.Ordinal))
            {
                failureStatus = StatusCodes.Status401Unauthorized;
                failureMessage = "Unauthorized: invalid password.";
                return false;
            }

            failureStatus = 0;
            failureMessage = string.Empty;
            return true;
        }

        public async ValueTask DisposeAsync()
        {
            if (_host is null)
                return;

            await _host.StopAsync();
            _host.Dispose();
            _host = null;
        }
    }
}
