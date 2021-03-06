(load "microKanren.scm")

(define-syntax Zzz
  (syntax-rules ()
    ((_ g) (lambda (s/c) (lambda () (g s/c))))))

(define-syntax conj+
  (syntax-rules ()
    ((_ g) (Zzz g))
    ((_ g0 g ...) (conj (Zzz g0) (conj+ g ...)))))

(define-syntax disj+
  (syntax-rules ()
    ((_ g) (Zzz g))
    ((_ g0 g ...) (disj (Zzz g0) (disj+ g ...)))))

(define-syntax fresh
  (syntax-rules ()
    ((_ () g0 g ...) (conj+ g0 g ...))
    ((_ (x0 x ...) g0 g ...)
     (call/fresh
      (lambda (x0)
        (fresh (x ...) g0 g ...))))))

(define-syntax conde
  (syntax-rules ()
    ((_ (g0 g ...) ...) (disj+ (conj+ g0 g ...) ...))))

(define-syntax run
  (syntax-rules ()
    ((_ n (x ...) g0 g ...)
     (map reify-1st (take n (call/goal (fresh (x ...) g0 g ...)))))))

(define-syntax run*
  (syntax-rules ()
    ((_ (x ...) g0 g ...)
     (map reify-1st (take-all (call/goal (fresh (x ...) g0 g ...)))))))

(define empty-state '(() () . 0))

(define (call/goal g) (g empty-state))

(define (pull $)
  (if (procedure? $) (pull ($)) $))

(define (take-all $)
  (let (($ (pull $)))
    (if (null? $) '() (cons (car $) (take-all (cdr $))))))

(define (take n $)
  (if (zero? n) '()
      (let (($ (pull $)))
        (if (null? $) '() (cons (car $) (take (- n 1) (cdr $)))))))

(define (reify-1st s/c)
  (let ([v (resolve (var 0) (car s/c))])
    (let-values ([(res _) (reify-s v '())])
      res)))

(define (resolve term subst)
  (cond [(var? term)
         (let ([e (or (find-class term subst) (eqn term '() 0 '()))])
           (if (null? (eqn-terms e)) (eqn-var e) (resolve (car (eqn-terms e)) subst)))]
        [(pair? term) (cons (resolve (car term) subst)
                            (resolve (cdr term) subst))]
        [else term]))

(define (reify-s t names)
  (cond [(var? t)
         (let ([name (assv t names)])
           (if name
               (values (cdr name) names)
               (let ([name (reify-name (length names))])
                 (values name (cons (cons t name) names)))))]
        [(pair? t)
         (let*-values ([(car-name names~) (reify-s (car t) names)]
                       [(cdr-name names~) (reify-s (cdr t) names~)])
           (values (cons car-name cdr-name) names~))]
        [else (values t names)]))

(define (reify-name n)
  (string->symbol
   (string-append "_." (number->string n))))

(define (fresh/nf n f)
  (letrec
      ((app-f/v*
        (lambda (n v*)
          (cond
            ((zero? n) (apply f (reverse v*)))
            (else (call/fresh
                   (lambda (x)
                     (app-f/v* (- n 1) (cons x v*)))))))))
    (app-f/v* n '())))
