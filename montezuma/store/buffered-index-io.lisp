(in-package #:montezuma)

(defclass buffered-index-ouput (index-output)
  ((buffer)
   (buffer-size :initarg :buffer-size)
   (buffer-start :initform 0)
   (buffer-position :initform 0))
  (:default-initargs
   :buffer-size 1024))

(defmethod initalize-instance :after ((self buffered-index-ouput))
  (with-slots (buffer buffer-size) self
    (setf buffer (make-string buffer-size))))

(defmethod write-byte ((self buffered-index-ouput) b)
  (with-slots (buffer buffer-size buffer-position) self
    (when (> buffer-position buffer-size)
      (flush self))
    (setf (aref buffer buffer-position) b)
    (incf buffer-position)))

(defmethod write-bytes ((self buffered-index-ouput) buffer length)
  (dotimes (i length)
    (write-byte self (aref buffer i))))

(defmethod flush ((self buffered-index-ouput))
  (with-slots (buffer buffer-position buffer-start) self
    (flush-buffer self buffer buffer-position)
    (incf buffer-start buffer-position)
    (setf buffer-position 0)))

(defmethod close ((self buffered-index-ouput))
  (flush self))

(defmethod pos ((self buffered-index-ouput))
  (with-slots (buffer-start buffer-position) self
    (+ buffer-start buffer-position)))

(defmethod seek ((self buffered-index-ouput) pos)
  (flush self)
  (with-slots (buffer-start) self
    (setf buffer-start pos)))

(defgeneric flush-buffer (buffered-index-ouput buffer length))


(defclass buffered-index-input (index-input)
  ((buffer)
   (buffer-size :initarg :buffer-size)
   (buffer-start :initform 0)
   (buffer-length :initform 0)
   (buffer-position :initform 0)))

(defmethod read-byte ((self buffered-index-input))
  (with-slots (buffer-position buffer-length buffer) self
    (when (>= buffer-position buffer-length)
      (refill self))
    (prog1 (aref buffer buffer-position)
      (incf buffer-position))))

(defmethod read-bytes ((self buffered-index-input) buffer offset length)
  (with-slots (buffer-size buffer-start buffer-position buffer-length) self
    (if (< length buffer-size)
	(dotimes (i length)
	  (setf (aref buffer (+ i offset)) (read-byte self)))
	(let ((start (pos self)))
	  (seek-internal self start)
	  (read-internal self buffer offset length)
	  (setf buffer-start (+ start length))
	  (setf buffer-position 0)
	  (setf buffer-length 0))))
  buffer)

(defmethod pos ((self buffered-index-input))
  (with-slots (buffer-start buffer-position) self
    (+ buffer-start buffer-position)))

(defmethod seek ((self buffered-index-input) pos)
  (with-slots (buffer-start buffer-length buffer-position) self
    (if (and (> pos buffer-start)
	     (< pos (+ buffer-start buffer-length)))
	(setf buffer-position (- pos buffer-start))
	(progn
	  (setf buffer-start pos)
	  (setf buffer-position 0)
	  (setf buffer-length 0)
	  (seek-internal self pos)))))

(defgeneric read-internal (buffered-index-input buffer offset length))

(defgeneric seek-internal (buffered-index-input pos))

(defmethod refill ((self buffered-index-input))
  (with-slots (buffer-start buffer-position buffer-size buffer-length buffer)
      self
    (let* ((start (+ buffer-start buffer-position))
	   (last (+ start buffer-size)))
      (when (> last (size self))
	(setf last (size self)))
      (setf buffer-length (- last start))
      (when (<= buffer-length 0)
	(error "EOF"))

      (when (null buffer)
	(setf buffer (make-string buffer-size)))

      (read-internal self buffer 0 buffer-length)

      (setf buffer-start start)
      (setf buffer-position 0))))
