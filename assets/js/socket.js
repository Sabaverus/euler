// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

window.channel = socket.channel("services", {})

let innCheckForm = document.getElementById("inn-form")
let innCheckFormInput  = document.getElementById("inn-form-input")
let innCheckFormSubmit  = document.getElementById("inn-form-submit")
let innCheckFormMessages  = document.getElementById("inn-form-messages")

let inputHelper = document.querySelectorAll('.inn-input-helper')

innCheckForm.addEventListener("submit", function(e) {
    e.preventDefault()

    let value = innCheckFormInput.value
    
    switch (value.length) {
      case 10:
      case 12:
        channel.push("services:inn-check", {inn: innCheckFormInput.value})
        innCheckFormInput.value = ""
        innCheckFormSubmit.disabled = true
        innCheckFormMessages.innerText = ''
        break;
      default:
        innCheckFormMessages.innerText = 'ИНН должен состоять из 10 или 12 символов'
    }
})

channel.on("services:inn-check", payload => {
  if(payload.error) {
    innCheckFormMessages.innerText = payload.error.message
  } else {
    window.innList.push(payload.result)
  }

  innCheckFormSubmit.disabled = false
})

channel.join()
  .receive("ok", resp => {})
  .receive("error", resp => {})

///////////////////////////

inputHelper.forEach(function(v, k) {
  v.addEventListener('click', function(e) {
    e.preventDefault()
    innCheckFormInput.value = e.target.innerText
  })
})

export default socket
