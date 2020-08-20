export default class InnList {

    data = []
    htmlList = null
    limit = 10

    constructor(htmlList, data) {
        this.htmlList = htmlList
        this.data = data
    }

    push(entry) {
        this.data.unshift(entry)
        this.data = this.data.slice(0, this.limit)
        
        this.data.sort(function(a, b){
            return new Date(b.time) - new Date(a.time);
        })

        this.render()
    }

    render() {

        let content = ""
        this.data.forEach(el => {
            let li = document.createElement("li")
            let result = el.result ? "корректен" : "некорректен"
            li.innerHTML = `<span>[${this.formatDate(el.time)}]</span> ${el.inn} : ${result}`

            content += li.outerHTML
        })
        this.htmlList.innerHTML = content
    }

    formatDate(date) {
        var d = new Date(date),
            month = '' + (d.getMonth() + 1),
            day = '' + d.getDate(),
            year = d.getFullYear(),
            hour = d.getHours(),
            minutes = '' + d.getMinutes();
      
        if (month.length < 2) 
            month = '0' + month;
        if (day.length < 2) 
            day = '0' + day;
        if (minutes.length < 2) 
            minutes = '0' + minutes;
      
        return day + '.' + month + '.' + year  + ' ' + hour + ":" + minutes;
    }
}