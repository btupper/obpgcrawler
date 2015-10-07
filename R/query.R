#' A basic query function to retrieve one or more datasets
#'
#' @export
#' @param top character, uri of the top catalog
#' @param platform character, the name of the platform (MODISA, MODIST, OCTS, SeaWiFS, VIIRS, etc.)
#' @param product character, the product type (L3SMI, etc.)
#' @param year character or numeric, four digit year(s) - ignored if what is not 'all'
#' @param day character or numeric, three digit year of day(s) - ignored if what is not 'all'.
#'    You can improve efficiency by preselecting days for months, days, or seasons.
#' @param what character, optional filters
#'   \itemize{
#'       \item{all - return all occurences, the default, used with year and day, date_filter = NULL}
#'       \item{most_recent - return only the most recent, date_filter = NULL}
#'       \item{within - return the occurrences bounded by date_filter first and secomd elements}
#'       \item{before - return the occurences prior to the first date_filter element}
#'       \item{after - return the occurrences after the first date_filter element}
#'    }
#' @param date_filter POSIXct one or two element vector populated according to
#'    the \code{what} parameter.  By default NULL.  It is an error to not match 
#'    the value of date_filter  
#' @param greplargs list or NULL, if a list the provide two elements,
#'    pattern=character and fixed=logical, which are arguments for \code{grepl} If fixed is FALSE
#'    then be sure to provide a regex for the pattern value.
#' @param verbose logical, by default FALSE
#' @return list of DatasetRefClass or NULL
#' @examples
#'    \dontrun{
#'       query <- obpg_query(
#'          top = 'http://oceandata.sci.gsfc.nasa.gov/opendap/catalog.xml',
#'          platform = 'MODISA', 
#'          product = 'L3SMI',
#'          what = 'most_recent',
#'          greplargs = list(pattern='8D_CHL_chlor_a_4km', fixed = TRUE))
#'       query <- obpg_query( 
#'          top = 'http://oceandata.sci.gsfc.nasa.gov/opendap/catalog.xml',
#'          platform = 'MODISA', 
#'          product = 'L3SMI',
#'          what = 'within',
#'          date_filter = as.POSIXct(c("2008-01-01", "2008-06-01"), format = "%Y-%m-%d"),
#'          greplargs = list(
#'             chl = list(pattern='8D_CHL_chlor_a_4km', fixed = TRUE),
#'             sst = list(pattern='8D_SST_sst_4km', fixed = TRUE)) )
#'    }
#' @seealso \code{\link{get_monthdays}}, \code{\link{get_8days}} and \code{\link{get_seasondays}}
obpg_query <- function(
   top = 'http://oceandata.sci.gsfc.nasa.gov/opendap/catalog.xml',
   platform = 'MODISA', 
   product = 'L3SMI',
   year = format(as.POSIXct(Sys.Date()), "%Y"),
   day = format(as.POSIXct(Sys.Date()), "%j"),
   what = c("all", "most_recent", "within", "before", "after")[1],
   date_filter = NULL,
   greplargs = NULL,
   verbose = FALSE) {
   
   # Determine if a vector of names match the greplargs 
   # @param x a vector of names
   # @param greplargs NULL, vector or list
   # @return logical vector
   grepl_it <- function(x, greplargs = NULL){
      ix <- rep(FALSE, length(x))
      if (is.null(greplargs)) return(!ix)
      if (!is.list(greplargs[[1]])) greplargs <- list(greplargs)
      
      for (g in greplargs){
            ix <- ix | grepl(g[['pattern']], x, fixed = g[['fixed']])
      }
      ix
   }
   
   # Used to scan 'all' days for the listed year
   # Product CatalogRefClass
   # year one or more character in YYYY format
   # day one or more charcater in format JJJ
   # greplargs list of one or more grepl args
   get_all <- function(Product, year, day, greplargs = NULL) {
      #all for a given YEAR/DAY
      R <- NULL
      Years <- Product$get_catalogs()
      Y <- Years[year]
      if (!is.null(Y)){
         for (y in Y){
            Days <- y$GET()$get_catalogs()
            D <- Days[day]
            if (!is.null(D)){
               for (d in D){
                  d <- d$GET()
                  if (!is.null(d)){
                     datasets <- d$get_datasets()
                     ix <- grepl_it(names(datasets), greplargs)
                     if (any(ix)) R[names(datasets)[ix]] <- datasets[ix]
                  } # d is !null
               } # day loop
            } # day is found
        } # year loop 
      } #year is found   
      return(R)
   }
   
   Top <- get_catalog(top[1], verbose = verbose)
   if (is.null(Top)) {
      cat("error getting catalog for", top[1], "\n")
      return(NULL)
   }
   
   Platform <- Top$get_catalogs()[[platform[1]]]$GET()
   if (is.null(Platform)) {
      cat("error getting catalog for", platform[1], "\n")
      return(NULL)
   }
   
   Product <- Platform$get_catalogs()[[product[1]]]$GET()
   if (is.null(Product)) {
      cat("error getting catalog for", platform[1], "\n")
      return(NULL)
   }
   
   if (is.numeric(year)) year <- sprintf("%0.4i",year)
   if (is.numeric(day)) day <- sprintf("%0.3i", day)
   
   what <- tolower(what[1])
   R <- list()
   if (what == "most_recent"){
      while(length(R) == 0){
         Years <- Product$get_catalogs()
         for (y in rev(names(Years))){
            Y <- Years[[y]]$GET()
            Days <- Y$get_catalogs()
            for (d in rev(names(Days))){
               D <- Days[[d]]$GET()
               datasets <- D$get_datasets()
               ix <- grepl_it(names(datasets), greplargs)
               if (any(ix)){
                  R <- datasets[ix]
                  break
               }
               if (length(R) != 0){ break }
            } #days 
            if (length(R) != 0){ break }
         } #years
      }
   
   } else if (what %in% c('within', "before", "after")){
   
      if (is.null(date_filter)){
         cat("if what is 'within', 'before' or 'after' then date_filter must be provided\n")
         return(NULL)
      }
      if ((what == 'within') && (length(date_filter) < 2) ) {
         cat("if what is 'within' then date_filter have [begin,end] elements\n")
         return(NULL)
      }   
      if (!inherits(date_filter, "POSIXct")){
         cat("if what is 'within', 'before' or 'after' then date_filter must be POSIXct class\n")
         return(NULL)
      }          
      
      # compute the beginning and end
      tbounds <-   switch(tolower(what),
            'within' = date_filter[1:2],
            'after' = c(date_filter[1], as.POSIXct(Sys.time())), # from then to present
            'before' = c( as.POSIXct("1990-01-01 00:00:00"), date_filter[1]) ) # from 1990 to then
      # convert to daily steps
      tsteps <- seq(tbounds[1], tbounds[2], by = 'day')
      year <- format(tsteps, "%Y")
      day <- format(tsteps,"%j")
      
      yd <- split(day, year)
      # note how this differs from what = 'all', here we explicitly iterate through
      # the years (days may be different for each year
      for (i in seq_along(yd)){
         y <- names(yd)[i]
         R[[y]] <- get_all(Product, y, day, greplargs = greplargs)
      }

      R <- unlist(R, use.names = FALSE)
      names(R) <- sapply(R, function(x) x$name)
   
   } else {
      # retrieve the days from the years specified
      R <- get_all(Product, year, day, greplargs = greplargs)
   }
   
   # if none found then we return NULL (not an empty list)
   if (length(R) == 0) R <- NULL
   if (verbose){
      cat(sprintf("obpg_query: retrieved %i records\n", length(R)))
   }
   invisible(R)   
}

