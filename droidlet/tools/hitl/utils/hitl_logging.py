"""
Copyright (c) Facebook, Inc. and its affiliates.

The hitl_logging.py include a HitlLogging class for logging in HiTL module.
"""

from datetime import datetime, timezone
import logging
import os
import inspect

HITL_TMP_DIR = (
    os.environ["HITL_TMP_DIR"] if os.getenv("HITL_TMP_DIR") else f"{os.path.expanduser('~')}/.hitl"
)

DEFAULT_LOG_FORMATTER = logging.Formatter(
    "%(asctime)s [%(filename)s:%(lineno)s - %(funcName)s() %(levelname)s]: %(message)s"
)


class HitlLogging:
    """
    The HitlLogging class is a wrapper for the python basic logging,
    allows the caller class to registering for a logger name and logs into separate files.

    The logger generated by this class provides same APIs as the python logging library.

    The log would be output to both console and a log file, the log file is located under the HiTL temporary directory
    following the below format:
        {Hitl Tmp Dir}/{Batch Id}/{Logger Name}{Timestamp}.log

    Parameters:
        - batch_id:     required - batch_id of the hitl jobs
        - logger_name:  optional, default is set to caller class name
        - formatter:    optional, default is DEFAULT_LOG_FORMATTER
        - level:        optional, default is logging.WARNING (same as python logging module)
    """

    def __init__(
        self,
        batch_id: int,
        logger_name=None,
        formatter=DEFAULT_LOG_FORMATTER,
        level=logging.WARNING,
    ):
        # Get caller class to use as logger name if logger name is not specified
        if logger_name is None:
            logger_name = inspect.stack()[1][0].f_locals["self"].__class__.__name__

        # get timestamp to differentiate different instance
        timestamp = datetime.now(timezone.utc).isoformat()

        logger_name = f"{logger_name}{timestamp}"

        log_dir = os.path.join(HITL_TMP_DIR, f"{batch_id}/pipeline_logs")
        os.makedirs(log_dir, exist_ok=True)

        log_file = f"{log_dir}/{logger_name}.log"
        fh = logging.FileHandler(log_file)
        fh.setFormatter(formatter)

        sh = logging.StreamHandler()
        sh.setFormatter(formatter)

        logger = logging.getLogger(logger_name)

        logger.setLevel(level)
        logger.addHandler(fh)
        logger.addHandler(sh)

        self._logger = logger
        self._log_file = log_file

    def get_logger(self):
        return self._logger

    def get_log_file(self):
        return self._log_file

    def shutdown(self):
        for handler in self._logger.handlers:
            self._logger.removeHandler(handler)
            handler.close()
