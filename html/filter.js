/*
 * JS Filter list
 */

var filterNames = []
var filterData = []
var onClickFunctionName = ""

function setFilterListOptions(strings, data, onClick) {
    filterNames = strings
    filterData = data
    onClickFunctionName = onClick
}

function filterList() {
  // Declare variables
  var input, filter, ul, i, txtValue;
  input = document.getElementById('filterInput');
  filter = input.value.toUpperCase();
  ul = document.getElementById("filterList");

  if (filter.length <= 2) {
      filter = "@%@%@"
  }
  let html = []
  // Loop through all list items, and hide those who don't match the search query
  for (i = 0; i < filterNames.length; i++) {
      txtValue = filterNames[i]
      if (txtValue.toUpperCase().indexOf(filter) > -1) {
          html.push(`<li onclick='${onClickFunctionName}(\"${filterData[i]}\")'>${filterNames[i]}</li>`)
      }
  }
  ul.innerHTML = html.join("")
}

function hideFilterList() {
    var ul = document.getElementById("filterList");
    ul.innerHTML = ""
}
