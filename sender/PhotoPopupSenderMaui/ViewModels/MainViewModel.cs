using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PhotoPopupSenderMaui.ViewModels;

/// <summary>
/// ViewModel for the main screen. Handles photo selection, preview and upload to the Windows receiver.
/// </summary>
public partial class MainViewModel : ObservableObject
{
    // MARK: - Observable properties

    [ObservableProperty]
    private string baseUrl = "http://192.168.2.20:5055";

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(SendCommand))]
    [NotifyPropertyChangedFor(nameof(HasPreviewImage))]
    private ImageSource? previewImage;

    /// <summary>True when a preview image is available; used to show/hide the image preview.</summary>
    public bool HasPreviewImage => PreviewImage is not null;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(SendCommand))]
    [NotifyPropertyChangedFor(nameof(IsNotUploading))]
    [NotifyPropertyChangedFor(nameof(SendButtonText))]
    private bool isUploading;

    [ObservableProperty]
    private string statusText = "Choose a photo to get started.";

    /// <summary>True when no upload is in progress; used to enable/disable photo buttons.</summary>
    public bool IsNotUploading => !IsUploading;

    /// <summary>Label text for the send button depending on upload state.</summary>
    public string SendButtonText => IsUploading ? "Sending…" : "✈️  Send to PC";

    private byte[]? _jpegData;

    // Shared HttpClient instance to avoid socket exhaustion
    private static readonly HttpClient _httpClient = new();

    // MARK: - Commands

    /// <summary>Picks a photo from the device photo library.</summary>
    [RelayCommand]
    private async Task PickPhotoAsync()
    {
        try
        {
            var result = await MediaPicker.Default.PickPhotoAsync(new MediaPickerOptions
            {
                Title = "Choose Photo"
            });
            if (result is null) return;
            await LoadPreviewAsync(result);
        }
        catch (Exception ex)
        {
            StatusText = $"Could not open photo library: {ex.Message}";
        }
    }

    /// <summary>Opens the camera to take a new photo.</summary>
    [RelayCommand]
    private async Task TakePhotoAsync()
    {
        if (!MediaPicker.Default.IsCaptureSupported)
        {
            StatusText = "Camera not available on this device.";
            return;
        }
        try
        {
            var result = await MediaPicker.Default.CapturePhotoAsync();
            if (result is null) return;
            await LoadPreviewAsync(result);
        }
        catch (Exception ex)
        {
            StatusText = $"Could not take photo: {ex.Message}";
        }
    }

    /// <summary>Sends the selected photo to the configured Windows receiver URL.</summary>
    [RelayCommand(CanExecute = nameof(CanSend))]
    private async Task SendAsync()
    {
        if (_jpegData is null) return;

        IsUploading = true;
        try
        {
            // Trim URL and remove trailing slashes
            var trimmed = BaseUrl.Trim().TrimEnd('/');
            if (!Uri.TryCreate($"{trimmed}/push-photo", UriKind.Absolute, out var url))
            {
                StatusText = "Invalid URL.";
                return;
            }

            StatusText = "Uploading…";
            await UploadJpegAsync(url, _jpegData);
            StatusText = "Sent ✅ (popup should now appear on your PC)";
        }
        catch (Exception ex)
        {
            StatusText = $"Upload failed: {ex.Message}";
        }
        finally
        {
            IsUploading = false;
        }
    }

    private bool CanSend() => PreviewImage is not null && !IsUploading;

    // MARK: - Helpers

    /// <summary>Loads JPEG data and creates a preview ImageSource from a FileResult.</summary>
    private async Task LoadPreviewAsync(FileResult file)
    {
        StatusText = "Loading photo…";
        try
        {
            await using var stream = await file.OpenReadAsync();
            using var ms = new MemoryStream();
            await stream.CopyToAsync(ms);
            _jpegData = ms.ToArray();
            var capturedData = _jpegData;
            PreviewImage = ImageSource.FromStream(() => new MemoryStream(capturedData));
            StatusText = "Ready to send ✅";
        }
        catch (Exception ex)
        {
            StatusText = $"Error loading photo: {ex.Message}";
        }
    }

    /// <summary>Performs a multipart/form-data POST with the JPEG file to the given URL.</summary>
    private static async Task UploadJpegAsync(Uri url, byte[] jpegData)
    {
        using var content = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(jpegData);
        fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg");
        content.Add(fileContent, "file", "photo.jpg");

        var response = await _httpClient.PostAsync(url, content);
        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            throw new HttpRequestException(
                string.IsNullOrWhiteSpace(body) ? $"HTTP {(int)response.StatusCode}" : body,
                null,
                response.StatusCode);
        }
    }
}
