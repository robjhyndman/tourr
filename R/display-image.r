#' Image tour path animation.
#'
#' Animate a 1d tour path with an image plot.  This animation requires a 
#' different input data structure, a 3d array.  The first two dimensions are
#' locations on a grid, and the 3rd dimension gives the observations to be 
#' mixed with the tour.
#'
#' @param data matrix, or data frame containing numeric columns
#' @param tour_path tour path generator, defaults to the grand tour
#' @param ... other arguments passed on to \code{\link{animate}}
#' @seealso \code{\link{animate}} for options that apply to all animations
#' @keywords hplot
#' @examples
#' str(ozone)
#' animate_image(ozone)
animate_image <- function(data, tour_path = grand_tour(1), ...) {


  animate2(
    data = data, tour_path = tour_path, 
    display = display_image(data,...), ...
  )
}


display_image <- function(data,...)
{

#  xs <- ys <- zs<- NULL
  
    xs <<- dim(data)[1]
    ys <<- dim(data)[2]
    zs <<- dim(data)[3]
print(head(data))
    dim(data) <<- c(xs * ys, zs)


  render_frame <- function() { 
    blank_plot(xlim = c(1, xs), ylim = c(1, xs))
  }
  
  render_data <- function(data, proj, geodesic) {
  print(head(data))
    z <- data %*% proj
    dim(z) <- c(xs, ys)
    image(
      x = seq_len(xs), y = seq_len(ys), 
      z = t(z), 
      zlim = c(-2, 2), add = TRUE
    )
  }
  
  list(
    init = nul,
    render_frame = render_frame,
    render_transition = nul,
    render_data = render_data,
    render_target = nul
  )

}