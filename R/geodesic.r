#' Generate geodesic path.
#'
#' Wrap basis generation method with a function that keeps computes the
#' geodesic interpolation from the previous frame to the next frame, and
#' provides convenient access to all the information about the path.
#'
#' Frozen variables allow us to keep certain values of the projection
#' fixed and generate a geodesic across the subspace generated by those
#'
#' @param new_target_f function that generates new frame, with previous
#'   frame as argument
#' @keywords internal
#' @export
#' @return
#'   \item{interpolate}{A function with single parameter in [0, 1] that
#'     returns an interpolated frame between the current and future frames.
#'     0 gives the current plane, 1 gives the new target frame in plane of
#'     current frame.}
#'   \item{dist}{The distance, in radians, between the current and target
#'     frames.}
#'  \item{Fa}{The current frame.}
#'  \item{Fz}{The new target frame.}
#'  \item{tau}{The principle angles between the current and target frames.}
#'  \item{Ga}{The current plane.}
#'  \item{Gz}{The target plane.}
#' @examples
#' a <- basis_random(4, 2)
#' b <- basis_random(4, 2)
#' path <- geodesic_path(a, b)
#'
#' path$dist
#' all.equal(a, path$interpolate(0))
#' # Not true generally - a rotated into plane of b
#' all.equal(b, path$interpolate(1))
geodesic_path <- function(current, target, frozen = NULL, ...) {
  if (is.null(frozen)) {
    # Regular geodesic
    geodesic <- geodesic_info(current, target)

    interpolate <- function(pos) {
      step_fraction(geodesic, pos)
    }
  } else {
    # Frozen geodesic
    current_froz  <- freeze(current, frozen)
    target_froz   <- freeze(target,  frozen)

    geodesic <- geodesic_info(current_froz, target_froz)

    interpolate <- function(pos) {
      thaw(step_fraction(geodesic, pos), frozen)
    }
  }

  list(
    interpolate = interpolate,
    Fa = current,
    Fz = target,
    Ga = geodesic$Ga,
    Gz = geodesic$Gz,
    tau = geodesic$tau,
    dist = proj_dist(current, target)
  )
}

#' Calculate information required to interpolate along a geodesic path between
#' two frames.
#'
#' The methdology is outlined in
#' \url{http://www-stat.wharton.upenn.edu/~buja/PAPERS/paper-dyn-proj-algs.pdf}
#' and
#' \url{http://www-stat.wharton.upenn.edu/~buja/PAPERS/paper-dyn-proj-math.pdf},
#' and the code follows the notation outlined in those papers:
#'
#' \itemize{
#'   \item p = dimension of data
#'   \item d = target dimension
#'   \item F = frame, an orthonormal p x d matrix
#'   \item Fa = starting frame, Fz = target frame
#'   \item Fa'Fz = Va lamda  Vz' (svd)
#'   \item Ga = Fa Va, Gz = Fz Vz
#'   \item tau = principle angles
#' }
#' @keywords internal
#' @param Fa starting frame, will be orthonormalised if necessary
#' @param Fz target frame, will be orthonormalised if necessary
#' @param epsilon epsilon used to determine if an angle is effectively equal
#'   to 0
geodesic_info <- function(Fa, Fz, epsilon = 1e-6) {

  if (!is_orthonormal(Fa)) {
    # message("Orthonormalising Fa")
    Fa <- orthonormalise(Fa)
  }
  if (!is_orthonormal(Fz)) {
    # message("Orthonormalising Fz")
    Fz <- orthonormalise(Fz)
  }

  # if (Fa.equivalent(Fz)) return();
  # cat("dim Fa",nrow(Fa),ncol(Fa),"dim Fz",nrow(Fz),ncol(Fz),"\n")

  # Compute the SVD: Fa'Fz = Va lambda Vz' --------------------------------
  sv <- svd(t(Fa) %*% Fz)

  # R returns the svd from smallest to largest -------------------------------
  nc <- ncol(Fa)
  lambda <- sv$d[nc:1]
  Va <- sv$u[, nc:1]
  Vz <- sv$v[, nc:1]

  # Compute frames of principle directions (planes) ------------------------
  Ga <- Fa %*% Va
  Gz <- Fz %*% Vz

  # Form an orthogonal coordinate transformation --------------------------
  Ga <- orthonormalise(Ga)
  Gz <- orthonormalise(Gz)
  Gz <- orthonormalise_by(Gz, Ga)

  # Compute and check principal angles -----------------------
  tau <- suppressWarnings(acos(lambda))
  badtau <- is.nan(tau) | tau < epsilon
  Gz[, badtau] <- Ga[, badtau]
  tau[badtau] <- 0

  list(Va = Va, Ga = Ga, Gz = Gz, tau = tau)
}

#' Step along an interpolated path by fraction of path length.
#'
#' @keywords internal
#' @param interp interpolated path
#' @param fraction fraction of distance between start and end planes
step_fraction <- function(interp, fraction) {
  # Interpolate between starting and end planes
  #  - must multiply column wise (hence all the transposes)
  G <- t(
    t(interp$Ga) * cos(fraction * interp$tau) +
    t(interp$Gz) * sin(fraction * interp$tau)
  )

  # rotate plane to match frame Fa
  orthonormalise(G %*% t(interp$Va))
}

#' Step along an interpolated path by angle in radians.
#'
#' @keywords internal
#' @param interp interpolated path
#' @param angle angle, in radians
step_angle <- function(interp, angle) {
  step_fraction(interp, angle / sqrt(sum(interp$tau^2)))
}
