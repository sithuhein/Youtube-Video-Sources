//

function Render(html)
{
  while (HTMLContainer.lastElementChild) {
    HTMLContainer.removeChild(HTMLContainer.lastElementChild);
  }
    HTMLContainer.insertAdjacentHTML('beforeend',html);
}

function GetBaseUrlForResources(Resource)
{
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("ReturnBaseURL",
    [
        Microsoft.Dynamics.NAV.GetImageResource(Resource)
    ]);

}

var LoginWindow;

function LaunchURLinNewWindow(URL)
{
    LoginWindow = window.open(URL,'_blank',"toolbar=0,location=0,menubar=0,width=500,height=700");
}

function CloseWindow()
{
    LoginWindow.close();
}
function CloseCurrentWindow()
{
    window.close();
}

var TimerId;
function StartTimer()
{
    TimerId = window.setInterval(TimerTic,500);
}
function StopTimer()
{
    clearInterval(TimerId);
}
function TimerTic()
{
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("TimerTic",[],true);
}