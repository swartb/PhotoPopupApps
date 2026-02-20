namespace PhotoPopupSenderMaui;

public partial class MainPage : ContentPage
{
    public MainPage(ViewModels.MainViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
