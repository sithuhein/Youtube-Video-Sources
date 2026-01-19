function Init()
{
    container = document.getElementById("controlAddIn");

    container.innerHTML = `
    <deep-chat
      id="chat-element"
      demo="true"
      textInput='{"placeholder":{"text": "Welcome to the demo!"}}'
    ></deep-chat>`;
}