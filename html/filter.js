/*
 * JS Filter list
 */
function setFilterListOptions(strings, data, onClickFunctionName) {
    ul = document.getElementById("filterList");
    let html = []
    for (i=0; i < strings.length; i++) {
        html.push(`<li style='display:none;' onclick='${onClickFunctionName}(\"${data[i]}\")'>${strings[i]}</li>`)
    }
    ul.innerHTML = html.join("")
}

function filterList() {
  // Declare variables
  var input, filter, ul, li, a, i, txtValue;
  input = document.getElementById('filterInput');
  filter = input.value.toUpperCase();
  ul = document.getElementById("filterList");
  li = ul.getElementsByTagName('li');

  if (filter.length <= 2) {
      filter = "@%@%@"
  }
  // Loop through all list items, and hide those who don't match the search query
  for (i = 0; i < li.length; i++) {
    //a = li[i].getElementsByTagName("a")[0];
    txtValue = li[i].textContent || li[i].innerText;
    if (txtValue.toUpperCase().indexOf(filter) > -1) {
      li[i].style.display = "";
    } else {
      li[i].style.display = "none";
    }
  }
}

function hideFilterList() {
    var input, ul, li, i;
    input = document.getElementById('filterInput');
    ul = document.getElementById("filterList");
    li = ul.getElementsByTagName('li');

    input.value = ""
    // Loop through all list items, and hide those who don't match the search query
    for (i = 0; i < li.length; i++) {
        li[i].style.display = "none";
    }
}
