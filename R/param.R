# define R6 classes: Parentable, Param, DataHolder, Parameterized and ParamList
# port of GPflow/GPflow/param.py

#' A very simple class for objects in a tree, where each node contains a
#' reference to '_parent'.
##' This class can figure out its own name (by seeing what it's called by the
##' _parent's __dict__) and also recurse up to the highest_parent.
Parentable <- R6Class('Parentable',
                      public = list(

                        # enclosing env of parent
                        .parent_env = NULL,

                        # set the environment of the parent
                        .set_parent_env = function (parent)
                          self$.parent_env <- parent$.__enclos_env__,

                        `$<-` = function (x, i, value) {
                          # when setting values, if the new value is a parentable,
                          # tell it who its parent is
                          if (inherits(value, 'parentable'))
                            value$.set_parent_env(self)

                          # then assign
                          self[[i]] <- value

                        },

                        print = function (...) {
                          # find the classes ot which this object belongs and print them

                          classes <- class(self$clone())

                          main_class <- classes[1]
                          other_classes <- classes[-1]
                          other_classes <- other_classes[other_classes != 'R6']

                          if (length(other_classes) > 0) {
                            inheritance_msg <- sprintf('(inheriting from %s)\n',
                                                       paste(other_classes,
                                                             collapse = ' < '))
                          } else {
                            inheritance_msg <- ''
                          }

                          msg <- sprintf('%s object\n%s',
                                         main_class,
                                         inheritance_msg)
                          cat (msg)

                        },

                        # getstate <- function () {
                        #   d <- self.dict
                        #   d$pop('_parent')
                        #   return (d)
                        # },

                        # setstate = function (d) {
                        #   self$dict$update(d)
                        #   self$parent <- NULL
                        # }

                      ),
                      active = list(

                        # make name and long_name properties

                        # name = function () {
                        #   # An automatically generated name, given by the
                        #   # reference of the _parent to this instance
                        #   if (is.null(self$parent()))
                        #     return ('unnamed')
                        #
                        #   if (inherits(self$parent(), 'ParamList'))
                        #     return (sprintf('item%i', self$parent()$.list$index(self)))
                        #
                        #   # matches = [key for key, value in self$parent()$__dict__$items()
                        #   #            if value is self]
                        #   matches = 0
                        #
                        #   if (length(matches) == 0)
                        #     stop("mis-specified parent. This Param's .parent does not contain a reference to it.")
                        #
                        #   if (length(matches) > 1)
                        #     stop("This Param appears to be doubly referenced by a parent")
                        #
                        #   matches[1]
                        # },

                        # long_name = function () {
                        #   # This is a unique identifier for a param object
                        #   # within a structure, made by concatenating the names
                        #   # through the tree.
                        #   if (is.null(self$parent()))
                        #     return (self$name())
                        #
                        #   paste(self$parent()$long_name(),
                        #         self$name(),
                        #         collapse = '.')
                        # }

                        parent = function (value) {
                          # get the parent object from its environment
                          if (missing(value))
                            self$.parent_env$self
                          else
                            self$.parent_env$self <- value
                          },

                        highest_parent = function (value) {
                          # A reference to the top of the tree, usually a Model
                          # instance
                          if (missing(value)) {
                            if (is.null(self$parent))
                              self
                            else
                              self$parent$highest_parent
                          } else {
                            if (is.null(self$parent))
                              self <- value
                            else
                              self$parent$highest_parent <- value
                          }

                        }


                      ))

Param <- R6Class('Param',
                 inherit = Parentable,

                 public = list(

                   .array = NULL,
                   .tf_array = NULL,
                   .log_jacobian = NULL,
                   prior = NULL,
                   fixed = FALSE,

                   initialize = function (array, transform = I) {
                     self$value <- array
                     self$transform <- transform
                   },

                   # get_parameter_dict = function (d)
                   #   d[[self$long_name]] <- self$value,
                   #
                   # set_parameter_dict = function (d)
                   #   self$value <- d[[self$long_name]],

                   # get_samples_df = function (samples) {
                   #   # Given a numpy array where each row is a valid free-state
                   #   # vector, return a pandas.DataFrame which contains the
                   #   # parameter name and associated samples in the correct form
                   #   # (e.g. with positive constraints applied).
                   #   # if (self$fixed)
                   #     # return (pd.Series([self.value for _ in range(samples.shape[0])], name=self.long_name))
                   #   start <- self$highest_parent()$get_param_index(self)[1]
                   #   end <- start + self$size - 1
                   #   samples <- samples[, start:end]
                   #   # samples <- samples.reshape((samples.shape[0],) + self.shape)
                   #   samples <- self$transform$forward(samples)
                   #   # return (pd.Series([v for v in samples], name=self.long_name))
                   # },

                   make_tf_array <- function (free_array) {
                     # free_array is a tensorflow vector which will be the optimisation
                     # target, i.e. it will be free to take any value.
                     # Here we take that array, and transform and reshape it so that it can be
                     # used to represent this parameter
                     # Then we return the number of elements that we've used to construct the
                     # array, so that it can be sliced for the next Param.

                     # fixed parameters are treated by tf.placeholder
                     if (self$fixed)
                       return (0)
                     free_size <- self$transform$free_state_size(self$shape)
                     x_free <- free_array[1:free_size]
                     mapped_array <- self$transform$tf_forward(x_free)
                     self$.tf_array <- tf$reshape(mapped_array, self$shape)
                     self$.log_jacobian <- self$transform$tf_log_jacobian(x_free)
                     return (free_size)
                   },

                   # get_free_state = function () {
                   #   # Take the current state of this variable, as stored in self.value, and
                   #   # transform it to the 'free' state.
                   #   # This is a numpy method.
                   #   if (self$fixed)
                   #     return (np.empty((0,), np_float_type))
                   #   return (self$transform$backward(self$value$flatten())))
                   # },

                   # get_feed_dict = function() {
                   #    # Return a dictionary matching up any fixed-placeholders to their values
                   #    d <- list()
                   #    if (self$fixed)
                   #      d[[self$.tf_array]] <- self$value
                   #    return (d)
                   # },

                   set_state = function (x) {
                     # Given a vector x representing the 'free' state of this Param, transform
                     # it 'forwards' and store the result in self._array. The values in
                     # self._array can be accessed using self.value
                     # This is a numpy method.
                     if (self$fixed)
                       return (0)
                     free_size <- self$transform$free_state_size(self$shape)
                     # new_array <- self$transform$forward(x[1:free_size])$reshape(self$shape)
                     # assert new_array.shape == self.shape
                     # self._array[...] = new_array
                     return (free_size)
                   },


                   build_prior <- function () {
                     # Build a tensorflow representation of the prior density.
                     # The log Jacobian is included.
                     if (is.null(self$prior))
                       return (tf$constant(0.0, float_type))
                     else if (is.null(self$.tf_array))  # pragma: no cover
                       stop ("tensorflow array has not been initialized")
                     else
                       return (self$prior$logp(self$.tf_array) + self$.log_jacobian)
                   },

                   `$<-` = function (x, i, value) {
                     # When some attributes are set, we need to recompile the tf model before
                     # evaluation.
                     self[[i]] <- value
                     if (i %in% recompile_keys)
                       self$highest_parent$.needs_recompile <- TRUE

                     # when setting the fixed attribute, make or remove a placeholder appropraitely
                      if (i == 'fixed') {
                        if (value)
                          self$.tf_array <- tf$placeholder(dtype = float_type,
                                                          shape = self$.array$shape,
                                                          name = self$name)
                        else
                          self$.tf_array = NULL
                      }
                   },

                   # could overload str.R6 for this?

                   # def __str__(self, prepend=''):
                   #   return prepend + \
                   # '\033[1m' + self.name + '\033[0m' + \
                   # ' transform:' + str(self.transform) + \
                   # ' prior:' + str(self.prior) + \
                   # (' [FIXED]' if self.fixed else '') + \
                   # '\n' + str(self.value)

                   getstate = function (self) {
                     d <- super$getstate()
                     d$pop('_tf_array')
                     d$pop('_log_jacobian')
                     return (d)
                   },

                   setstate = function (self) {
                     super$setstate(d)
                     self$.log_jacobian <- NULL
                     self$fixed <- self$fixed
                   },

                 # point 'value' at the array
                 active = list(
                   value = property('.array'),
                   shape = function (value) dim(self$.array),
                   size = function (value) prod(self$shape),

                 )
                 )

def __init__(self, array, transform=transforms.Identity()):
  Parentable.__init__(self)
self._array = np.asarray(np.atleast_1d(array), dtype=np_float_type)
self.transform = transform
self._tf_array = None
self._log_jacobian = None
self.prior = None
self.fixed = False
# DataHolder <- R6Class('DataHolder',
#                          inherit = Parentable,
#                          public = list(
#
#                            print = function (...) {
#                              cat ('DataHolder object\n')
#                            }
#
#                          ))

Parameterized <- R6Class('Parameterized',
                         inherit = Parentable,
                         public = list(

                           x = NULL,
                           .tf_mode = FALSE,

                           initialize = function () {
                             self$.tf_mode <- FALSE
                           },

                           tf_mode = function () {
                             on.exit(self$.end_tf_mode())
                             self$.begin_tf_mode()
                             return (self$clone())
                           },

                           .begin_tf_mode = function () {
                             self$.tf_mode <- TRUE
                           },

                           .end_tf_mode = function () {
                             self$.tf_mode <- FALSE
                           },

                           print = function (...) {
                             cat ('Parameterized object\n')
                           }

                           `$` <- function (x, i) {
                             # return a tensorflow array if `x` is in tf_mode,
                             # and the object containing that array otherwise
                             o <- x[[i]]

                             if (has(x, '.tf_mode') && x[['.tf_mode']] && has(o, '.tf_array'))
                               o <- o[['.tf_array']]

                             o
                           }

                         ))


ParamList <- R6Class('ParamList',
                         inherit = Parameterized,
                         public = list(

                           print = function (...) {
                             cat ('ParamList object\n')
                           }

                         ))
