container = document.getElementById("controlAddIn");
container.style.background = "red";

var heightindcator = window.frameElement.closest('div[class~="control-addin-form"]');
window.frameElement.style.height = (heightindcator.offsetHeight - 5).toString() + 'px';
window.frameElement.style.maxHeight = (heightindcator.offsetHeight - 5).toString() + 'px';

window.addEventListener('resize', function (event) {
    var heightindcator = window.frameElement.closest('div[class~="control-addin-form"]');
    window.frameElement.style.height = (heightindcator.offsetHeight - 5).toString() + 'px';
    window.frameElement.style.maxHeight = (heightindcator.offsetHeight - 5).toString() + 'px';
}, true);