library(rvest)

url <- "https://moneypuck.com/data.htm"
webpage <- read_html(url)

links <- webpage %>%
  html_nodes("a") %>%
  html_attr("href")

print(links)

links_to_download <- links[4:67]

print(links_to_download[1:5])

base_url <- "https://moneypuck.com/"

for (i in seq_along(links_to_download)) {
  full_url <- paste0(base_url, links_to_download[i])
  file_name <- sub(".*/(.*)\\.csv$", "\\1", links_to_download[i]) # Extract the base name without .csv
  year <- sub(".*/(\\d{4}).*", "\\1", links_to_download[i]) # Extract the year from the link
  destfile <- paste0("data/lake/moneypuck/", file_name, "_", year, ".rds")
  
  data <- read.csv(full_url) # Download the CSV data
  saveRDS(data, destfile) # Save as .rds
  message(i, " ", links_to_download[i])
}
