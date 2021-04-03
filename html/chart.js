/*
 Chart building code
 */

var chart
var chart_data
var direction = "on"
var expandedNode
var dependencyData
var dependencyFile = "https://raw.githubusercontent.com/adam-fowler/swift-dependency-graph/main/html/dependencies.json?v=9"
var rootName = "https://github.com/adam-fowler/swift-dependency-graph"
var nodeId = 0
var nodePositions = {}
var nodeToView

// load google chart
google.charts.load('current', {packages:["orgchart"]});
google.charts.setOnLoadCallback(loadDependencies);

parseQueryParams()

function parseQueryParams() {
    var queryDict = {}
    location.search.substr(1).split("&").forEach(function(item) {queryDict[item.split("=")[0]] = item.split("=")[1]})

    if (queryDict["package"] != undefined) {
        // root name without git extension. regex removes extension
        rootName = queryDict["package"].replace(/\.[^\//.]+$/, "")
    }
    if (queryDict["dependents"] != undefined && queryDict["dependents"] != 0) {
        direction = "to"
    }
}

function createChart() {
    // Create the chart.
    let container = document.getElementById('chart_div')
    chart = new google.visualization.OrgChart(container);

    container.addEventListener('click', function (e) {
        e.preventDefault();
        if (e.target.tagName.toUpperCase() === 'A') {
            chart.setSelection([]);
            gtag('event', 'view_link', {'event_label' : e.target.href})
            window.open(e.target.href, "_blank");
            drawChart()
        } else if (e.target.parentElement.tagName.toUpperCase() === 'A') {
            chart.setSelection([]);
            gtag('event', 'view_link', {'event_label' : e.target.parentElement.href})
            window.open(e.target.parentElement.href, "_blank");
            drawChart()
        } else {
            let selection = chart.getSelection()
            if (selection.length == 0) {
                return
            }
            let value = chart_data.getValue(selection[0].row, 0)
            let newRoot = value.split('#')[0]
            if (newRoot == "__next__") {
                let rootName = value.split('#')[1]
                var position = 1
                if (nodePositions[rootName] != undefined) {
                    position = nodePositions[rootName] + 1
                }
                nodePositions[rootName] = position
            }
            else if (newRoot == "__prev__") {
                let rootName = value.split('#')[1]
                var position = 0
                if (nodePositions[rootName] != undefined) {
                    position = nodePositions[rootName] - 1
                }
                nodePositions[rootName] = position
            }
            else if (newRoot == "__expand__") {
                expandedNode = value
                //nodeToView =
            }
            else if (newRoot == rootName) {
                if (direction == "on") { direction = "to" } else { direction = "on" }
            } else {
                rootName = newRoot
            }
            chart.setSelection([]);
            drawChart();
        }
    }, false);

}

function loadDependencies() {
    $.ajax({
           url : dependencyFile,
           success : function (data) {
               dependencyData = JSON.parse(data)
               let keys = Object.keys(dependencyData)
               let filterNames = keys.map(function(name) {return displayName(name)})
               setFilterListOptions(filterNames, keys, "selectRoot")
               createChart();
               drawChart()
           }
           });
}

function selectRoot(name) {
    rootName = name
    gtag('event', 'view_package', {'event_label' : rootName})
    direction = "on"
    hideFilterList()
    drawChart()
}

function displayName(name) {
    let split = name.split("/")
    if (split.length >= 2) {
        return `${split[split.length-2]}/${split[split.length-1]}`
    }
    return name
}

function idName(id) {
    return id.replace(/\W/g, '')
}
function renderName(name, id) {
    let split = name.split("/")
    if (split.length >= 2) {
        var html = []
        let id2 = idName(id)
        html.push(`<div id="${id2}" class='packagetitle'>${split[split.length-1]}</div>`)
        html.push(`<div class='packageowner'>${split[split.length-2]}`)
        html.push(`<a class='packagelink' href='${name}'><img src='images/pagelink.svg'/></a></div>`)
        return html.join("")
    }
    return name
}

function tooltipForName(name) {
    let node = dependencyData[name]
    if (node.error === "FailedToLoad") {
        return `${name}\nDependencies unavailable. Cannot find a Package.swift on the 'master' branch`
    } else if(node.error === "InvalidManifest") {
        return `${name}\nDependencies unavailable. Failed to load Package.swift.\nEither it is corrupt or is an unsupported version.\nVersions supported range from 4.0 to 5.0.`
    } else if(node.error === "Unknown") {
        return `${name}\nDependencies unavailable. Failed to load Package.swift`
    }
    return name
}

function addChildrenRows(data, rootName, level, rootNameCount, packagesAdded, stack = []) {
    nodeId += 1
    if (level == 0) {
        return
    }
    let maxPackages = 12
    let nodeId2 = nodeId
    let root = dependencyData[rootName]
    let numChildren = root[direction].length
    var position = 0

    if (nodePositions[rootName] != undefined) {
        position = nodePositions[rootName]
    }
    var packagesToDisplay = root[direction]
    // if viewing dependents limit number to 12
    if (direction == "to") {
        packagesToDisplay = packagesToDisplay.slice(position*maxPackages,(position+1)*maxPackages)
    }
    var rows = packagesToDisplay.map(function(name){return [{v:`${name}#${nodeId2}`, f:renderName(name, `${name}#${nodeId2}`)}, rootNameCount, tooltipForName(name)]})

    stack.push(rootName)
    // if we have already display a complete tree for a package and it has more than 4 children show expand box
    if (packagesAdded.has(rootName) && numChildren > 4) {
        let stackString = stack.join("#")
        let name = `__expand__#${stackString}`
        if (name != expandedNode) {
            let row = data.addRow([{v:name, f:`<h1 class="expand">\u2193</h1>`}, rootNameCount, "Show more ..."])
            //data.setRowProperty(row, "parent", )
            stack.pop()
            return
        }
    }

    // if node position is greater than zero than add previous node
    if (position > 0 && direction == "to") {
        data.addRow([{v:`__prev__#${rootName}`, f:"<h1>\u2190</h1>"}, rootNameCount, "Show more ..."])
    }
    data.addRows(rows)
    // if there are more than maxPackages to display then add a next button
    if (root[direction].length - position*maxPackages > maxPackages && direction == "to") {
        data.addRow([{v:`__next__#${rootName}`, f:"<h1>\u2192</h1>"}, rootNameCount, "Show more ..."])
    }


    packagesAdded.add(rootName)

    for(entry in packagesToDisplay) {
        let rootName = packagesToDisplay[entry]
        addChildrenRows(data, rootName, level-1, `${rootName}#${nodeId2}`, packagesAdded, stack)
    }
    stack.pop()
}

function drawChart() {
    var packagesAdded = new Set([])

    chart_data = new google.visualization.DataTable();

    chart_data.addColumn('string', 'Name');
    chart_data.addColumn('string', 'Parent');
    chart_data.addColumn('string', 'ToolTip');

    let root = dependencyData[rootName]
    nodeId = 0
    chart_data.addRows([[{v:rootName, f:renderName(rootName, rootName)}, "", tooltipForName(rootName)]]);
    addChildrenRows(chart_data, rootName, 8, rootName, packagesAdded)
    console.log(`Number of nodes ${nodeId}`)
    // set background
    var backgroundImages = {"to" : "images/solid-arrow-circle-down.svg", "on" : "images/solid-arrow-circle-up.svg"}
    document.body.style.backgroundImage = `url(${backgroundImages[direction]})`

    // Draw the chart, setting the allowHtml option to true for the tooltips.
    chart.draw(chart_data, {allowHtml:true, nodeClass:"chart-node", selectedNodeClass:"chart-node"});

    //var position = $('#httpsgithubcomvaporfluent73').offset();
    //console.log(position)
}
