using Microsoft.Extensions.Logging;

namespace PhotoPopupSenderMaui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>();

        builder.Services.AddTransient<MainPage>();
        builder.Services.AddTransient<ViewModels.MainViewModel>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
