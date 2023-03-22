<?php

define('MOODLE_INTERNAL', true);
class moodle_exception extends exception {};

require_once('casstring.units.class.php');

?>
file_search_maxima:append( [sconcat("${MAXIMAPOOL}/${VER}/maxima/###.{mac,mc}")] , file_search_maxima)$
file_search_lisp:append( [sconcat("${MAXIMAPOOL}/${VER}/maxima/###.{lisp}")] , file_search_lisp)$
file_search_maxima:append( [sconcat("${MAXIMAPOOL}/${VER}/tmp/logs/###.{mac,mc}")] , file_search_maxima)$
file_search_lisp:append( [sconcat("${MAXIMAPOOL}/${VER}/tmp/logs/###.{lisp}")] , file_search_lisp)$

STACK_SETUP(ex):=block(
    MAXIMA_VERSION_NUM_EXPECTED:41,
    MAXIMA_PLATFORM:"server",
    maxima_tempdir:"${MAXIMAPOOL}/${VER}/tmp/",
    IMAGE_DIR:"${MAXIMAPOOL}/${VER}/tmp/plots/",
    PLOT_SIZE:[450,300],
    PLOT_TERMINAL:"svg",
    PLOT_TERM_OPT:"dynamic font \",11\" linewidth 1.2",
    DEL_CMD:"rm",
    GNUPLOT_CMD:"gnuplot",
    MAXIMA_VERSION_EXPECTED:"5.41.0",
    URL_BASE:"!ploturl!",
<?php echo stack_cas_casstring_units::maximalocal_units(); ?>
    true)$
