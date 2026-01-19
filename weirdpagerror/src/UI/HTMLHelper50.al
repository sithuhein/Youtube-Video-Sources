controladdin "AL HTMLHelper50 Hgd"
{
    VerticalStretch = true;
    HorizontalStretch = true;
    Images = 'src/UI/Logo2.png', 'src/UI/httpclient_warning.jpg';
    RequestedHeight = 50;
    StartupScript = 'src/UI/Startup.js';
    Scripts = 'src/UI/Script.js';
    event RedirectReceived(Code: Text; State: Text);
    event ControlReady();
    event TimerTic();
    procedure LaunchURLinNewWindow(URL: Text);
    procedure StartTimer();
    procedure StopTimer();
    procedure CloseCurrentWindow();
    procedure CloseWindow();


    procedure Render(HTML: Text);
    event JavaScriptEvent();
    procedure GetBaseUrlForResources(Resource: Text);
    event ReturnBaseURL(URL: Text);
}