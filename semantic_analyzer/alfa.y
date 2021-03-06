%{
    #include "alfa.h"
    #include "generacion.h"
    #include "TablaSimbolos.h"
    #include "y.tab.h"
    #include <stdlib.h>
    #include <stdio.h>
    #include <stdarg.h>
    #include <stdbool.h>

    extern FILE *yyin;
    extern FILE *yyout;
    extern int yylex(void);
    extern int yyleng;

    extern int row;
    extern int col;
    extern int codigo_tok;

    TablaSimbolos *tabla_simbolos;
    bool local;
    bool en_explist;
    bool hay_ret;
    int tipo_actual;
    int clase_actual;
    int tam_vector_actual;
    
    int tipo_retorno_funcion_actual;
    
    int pos_parametro_actual;
    int num_parametros_actual;
    int pos_variable_local_actual;
    int num_variables_locales_actual;
    int num_parametros_llamada_actual;
    
    tipo_atributos atributos_actuales;

    int etiqueta = 1;
    
    int yyerror(char *s);
%}

%code requires {
    #include "alfa.h"
}

%union {
    tipo_atributos atributos;
}

/* Palabras reservadas */ 
%token TOK_MAIN
%token TOK_INT
%token TOK_BOOLEAN
%token TOK_ARRAY
%token TOK_FUNCTION
%token TOK_IF
%token TOK_ELSE
%token TOK_WHILE
%token TOK_SCANF
%token TOK_PRINTF
%token TOK_RETURN

/* Simbolos */
%token TOK_PUNTOYCOMA
%token TOK_COMA
%token TOK_PARENTESISIZQUIERDO
%token TOK_PARENTESISDERECHO
%token TOK_CORCHETEIZQUIERDO
%token TOK_CORCHETEDERECHO
%token TOK_LLAVEIZQUIERDA
%token TOK_LLAVEDERECHA
%token TOK_ASIGNACION
%token TOK_MAS
%token TOK_MENOS
%token TOK_DIVISION
%token TOK_ASTERISCO
%token TOK_AND
%token TOK_OR
%token TOK_NOT
%token TOK_IGUAL
%token TOK_DISTINTO
%token TOK_MENORIGUAL
%token TOK_MAYORIGUAL
%token TOK_MENOR
%token TOK_MAYOR

/* Identificadores  */
%token <atributos> TOK_IDENTIFICADOR

/* Constantes */ 
%token <atributos> TOK_CONSTANTE_ENTERA
%token TOK_TRUE
%token TOK_FALSE

/* Errores */
%token TOK_ERROR

%type <atributos> tipo
%type <atributos> exp
%type <atributos> constante
%type <atributos> constante_entera
%type <atributos> constante_logica
%type <atributos> fn_name
%type <atributos> fn_declaration
%type <atributos> comparacion
%type <atributos> idf_llamada_funcion
%type <atributos> elemento_vector
%type <atributos> if_exp
%type <atributos> if_else
%type <atributos> while_exp
%type <atributos> while_tok

/* Precedencia de operadores */
%left TOK_OR TOK_AND TOK_NOT
%left TOK_MENOR TOK_MAYOR TOK_IGUAL TOK_DISTINTO TOK_MENORIGUAL TOK_MAYORIGUAL
%left TOK_MAS TOK_MENOS
%left TOK_ASTERISCO TOK_DIVISION

%start programa

%%

programa:
    TOK_MAIN TOK_LLAVEIZQUIERDA declaraciones escritura_TS funciones escritura_main sentencias TOK_LLAVEDERECHA {
        escribir_fin(yyout);
    };

escritura_TS: 
    /* lambda */ {
        escribir_cabecera_bss(yyout, tabla_simbolos);
        escribir_subseccion_data(yyout);
        escribir_segmento_codigo(yyout);
    };

escritura_main:
    /* lambda */ {
        escribir_inicio_main(yyout);
    };

declaraciones:
    declaracion |
    declaracion declaraciones;

declaracion:
    clase identificadores TOK_PUNTOYCOMA;

clase:
    clase_escalar {
        clase_actual = ESCALAR;
        tam_vector_actual = 0;
    } |
    clase_vector {
        clase_actual = VECTOR;
    };

clase_escalar:
    tipo;

tipo:
    TOK_INT {
        tipo_actual = ENTERO;
        $$.tipo = ENTERO;
    } |
    TOK_BOOLEAN {
        tipo_actual = BOOLEANO; 
        $$.tipo = BOOLEANO;
    };

clase_vector:
    TOK_ARRAY tipo TOK_CORCHETEIZQUIERDO TOK_CONSTANTE_ENTERA TOK_CORCHETEDERECHO {
        if ($4.valor_entero < 1 || $4.valor_entero > MAX_TAM_VECTOR) {
            printf("Error semantico [lin %d, col %d]: Tamaño de vector invalido.\n", row, col);
            return PARAR_COMPILADOR;
        }

        tam_vector_actual = $4.valor_entero;
    };

identificadores:
    identificador |
    identificador TOK_COMA identificadores;

funciones:
    funcion funciones |
    /* lambda */;

funcion:
    fn_declaration sentencias TOK_LLAVEDERECHA {
        TablaSimbolos_terminar_funcion(tabla_simbolos);
        local = false;

        if (!hay_ret) {
            printf("Error semantico [lin %d, col %d]: la funcion %s no tiene ningun retorno.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
    };

fn_declaration:
    fn_name TOK_PARENTESISIZQUIERDO parametros_funcion TOK_PARENTESISDERECHO TOK_LLAVEIZQUIERDA declaraciones_funcion {
        TablaSimbolos_uso_global(tabla_simbolos, $1.lexema)->num_parametros = num_parametros_actual;
        TablaSimbolos_uso_global(tabla_simbolos, $1.lexema)->num_variables_locales = num_variables_locales_actual;
        TablaSimbolos_uso_local(tabla_simbolos, $1.lexema)->num_parametros = num_parametros_actual;
        TablaSimbolos_uso_local(tabla_simbolos, $1.lexema)->num_variables_locales = num_variables_locales_actual;
        strcpy($$.lexema, $1.lexema);
        
        declararFuncion(yyout, $1.lexema, num_variables_locales_actual);
    };

fn_name:
    TOK_FUNCTION tipo TOK_IDENTIFICADOR {
        if (TablaSimbolos_existe_global(tabla_simbolos, $3.lexema)) {
            printf("Error semantico [lin %d, col %d]: nombre de funcion %s ya utilizado.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }

        local = true;
        hay_ret = false;
        num_parametros_actual = 0;
        pos_parametro_actual = 0;
        num_variables_locales_actual = 0;
        pos_variable_local_actual = 1;
        tipo_retorno_funcion_actual = $2.tipo;

        strcpy(atributos_actuales.lexema, $3.lexema);
        atributos_actuales.categoria = FUNCION;
        atributos_actuales.tipo = $2.tipo;

        TablaSimbolos_declarar_funcion(tabla_simbolos, $3.lexema, &atributos_actuales);

        strcpy($$.lexema, $3.lexema);
    };

parametros_funcion:
    parametro_funcion resto_parametros_funcion |
    /* lambda */;

resto_parametros_funcion:
    TOK_PUNTOYCOMA parametro_funcion resto_parametros_funcion |
    /* lambda */;

parametro_funcion:
    tipo idpf;

declaraciones_funcion:
    declaraciones |
    /* lambda */;

sentencias:
    sentencia |
    sentencia sentencias;

sentencia:
    sentencia_simple TOK_PUNTOYCOMA |
    bloque;

sentencia_simple:
    asignacion |
    lectura |
    escritura |
    retorno_funcion;

bloque:
    condicional |
    bucle;

asignacion:
    TOK_IDENTIFICADOR TOK_ASIGNACION exp {
        if ((local && !TablaSimbolos_existe_local(tabla_simbolos, $1.lexema)) || (!local && !TablaSimbolos_existe_global(tabla_simbolos, $1.lexema))) {
            printf("Error semantico [lin %d, col %d]: El identificador %s no ha sido declarado.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $1.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $1.lexema));
        if (atributos_actuales.categoria == FUNCION) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a una funcion, por lo que no es asignable.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        } else if (atributos_actuales.clase == VECTOR) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un vector, por lo que no es asignable.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        } else if (atributos_actuales.tipo == BOOLEANO && $3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: Se intenta asignar a %s, de tipo booleano, una expresion de tipo entero.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;            
        } else if (atributos_actuales.tipo == ENTERO && $3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: Se intenta asignar a %s, de tipo entero, una expresion de tipo booleano.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;            
        }

        if (atributos_actuales.categoria == PARAMETRO) {
            escribirParametro(yyout, atributos_actuales.pos_parametro, num_parametros_actual);
            asignarDestinoEnPila(yyout, $3.es_direccion);
        } else {
            if (local && TablaSimbolos_existe_local_estricto(tabla_simbolos, $1.lexema)) {
                escribirVariableLocal(yyout, atributos_actuales.pos_variable_local);
                asignarDestinoEnPila(yyout, $3.es_direccion);
            } else {
                asignar(yyout, $1.lexema, $3.es_direccion);
            }
        }
    } |
    elemento_vector TOK_ASIGNACION exp { 
        if ($1.tipo == BOOLEANO && $3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: Se intenta asignar a %s, de tipo booleano, una expresion de tipo entero.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;            
        } else if ($1.tipo == ENTERO && $3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: Se intenta asignar a %s, de tipo entero, una expresion de tipo booleano.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;            
        }

        asignar_vector(yyout, $3.es_direccion);
    };

elemento_vector:
    TOK_IDENTIFICADOR TOK_CORCHETEIZQUIERDO exp TOK_CORCHETEDERECHO {
        if ((local && !TablaSimbolos_existe_local(tabla_simbolos, $1.lexema)) || (!local && !TablaSimbolos_existe_global(tabla_simbolos, $1.lexema))) {
            printf("Error semantico [lin %d, colEl identificador y no ha sido declarado. %d]: El identificador %s no ha sido declarado.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $1.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $1.lexema));
        if (atributos_actuales.categoria == FUNCION) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a una funcion, por lo que no es indexable.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        } else if (atributos_actuales.clase == ESCALAR) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un escalar, por lo que no es indexable.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        } else if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: Se esta indexando el vector %s con una expresion booleana, deberia ser una expresion de tipo entero.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        strcpy($$.lexema, $1.lexema);
        $$.tipo = atributos_actuales.tipo;
        $$.es_direccion = TRUE;

        escribir_elemento_vector(yyout, $1.lexema, atributos_actuales.numero_elementos, $3.es_direccion);
    };

condicional:
    if_exp TOK_LLAVEIZQUIERDA sentencias TOK_LLAVEDERECHA {
        ifthen_fin(yyout, $1.etiqueta);
    } |
    if_else TOK_LLAVEIZQUIERDA sentencias TOK_LLAVEDERECHA {
        ifthen_fin(yyout, $1.etiqueta);
    };

if_exp:
    TOK_IF TOK_PARENTESISIZQUIERDO exp TOK_PARENTESISDERECHO {
        if ($3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: Se esta usando una expresion entera como condicional en un IF, deberia ser una expresion booleana.\n", row, col);
            return PARAR_COMPILADOR;
        }

        ifthen_inicio(yyout, $3.es_direccion, etiqueta);
        $$.etiqueta = etiqueta;
        etiqueta++;
    };

if_else:
    if_exp TOK_LLAVEIZQUIERDA sentencias TOK_LLAVEDERECHA TOK_ELSE {
        ifthenelse_fin_then(yyout, $1.etiqueta);
        $$.etiqueta = $1.etiqueta;
    };

bucle:
    while_exp TOK_LLAVEIZQUIERDA sentencias TOK_LLAVEDERECHA {
        while_fin(yyout, $1.etiqueta);
    };

while_exp:
    while_tok TOK_PARENTESISIZQUIERDO exp TOK_PARENTESISDERECHO {
        if ($3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: Se esta usando una expresion entera como condicional en un WHILE, deberia ser una expresion booleana.\n", row, col);
            return PARAR_COMPILADOR;
        }

        while_exp_pila(yyout, $3.es_direccion, $1.etiqueta);
        $$.etiqueta = $1.etiqueta;
    };

while_tok:
    TOK_WHILE {
        while_inicio(yyout, etiqueta);
        $$.etiqueta = etiqueta;
        etiqueta++;
    };

lectura:
    TOK_SCANF TOK_IDENTIFICADOR {
        if ((local && !TablaSimbolos_existe_local(tabla_simbolos, $2.lexema)) || (!local && !TablaSimbolos_existe_global(tabla_simbolos, $2.lexema))) {
            printf("Error semantico [lin %d, col %d]: El identificador %s no ha sido declarado.\n", row, col, $2.lexema);
            return PARAR_COMPILADOR;
        }
        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $2.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $2.lexema));
        if (atributos_actuales.categoria == FUNCION) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a una funcion, pero scanf recibe como argumento un escalar.\n", row, col, $2.lexema);
            return PARAR_COMPILADOR;
        } else if (atributos_actuales.clase == VECTOR) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un vector, pero scanf recibe como argumento un escalar.\n", row, col, $2.lexema);
            return PARAR_COMPILADOR;
        }

        leer(yyout, $2.lexema, atributos_actuales.tipo);
    };

escritura:
    TOK_PRINTF exp {
        escribir(yyout, $2.es_direccion, $2.tipo);
    };

retorno_funcion:
    TOK_RETURN exp { 
        if (!local) {
            printf("Error semantico [lin %d, col %d]: Se ha declarado un RETURN fuera de una funcion, deberia estar declarado dentro de una funcion.\n", row, col);
            return PARAR_COMPILADOR;
        } else if (tipo_retorno_funcion_actual == ENTERO && $2.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: El tipo de retorno de una funcion es ENTERO, pero se esta devolviendo un parametro de tipo BOOLEANO.\n", row, col);
            return PARAR_COMPILADOR;
        } else if (tipo_retorno_funcion_actual == BOOLEANO && $2.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: El tipo de retorno de una funcion es BOOLEANO, pero se esta devolviendo un parametro de tipo ENTERO.\n", row, col);
            return PARAR_COMPILADOR;
        }

        hay_ret = true;
        retornarFuncion(yyout, $2.es_direccion);
    };

exp:
    exp TOK_MAS exp /* Testeada */ {
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una suma.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una suma.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;

        sumar(yyout, $1.es_direccion, $3.es_direccion);
    } |
    exp TOK_MENOS exp /* Testeada */ { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una resta.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una resta.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;

        restar(yyout, $1.es_direccion, $3.es_direccion);
    } |
    exp TOK_DIVISION exp /* Testeada */ {
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una division.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una division.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;

        dividir(yyout, $1.es_direccion, $3.es_direccion);
    } |
    exp TOK_ASTERISCO exp /* Testeada */ {
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una multiplicacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una multiplicacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;

        multiplicar(yyout, $1.es_direccion, $3.es_direccion);
    } |
    TOK_MENOS exp /* Testeada */ {
        if ($2.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en un cambio de signo.\n", row, col, $2.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;

        cambiar_signo(yyout, $2.es_direccion);
    } |
    exp TOK_AND exp /* Testeada */ {
        if ($1.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un entero, pero se usa en un Y logico.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un entero, pero se usa en un Y logico.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        y(yyout, $1.es_direccion, $3.es_direccion);
    } |
    exp TOK_OR exp {
        if ($1.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un entero, pero se usa en un O logico.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un entero, pero se usa en un O logico.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        o(yyout, $1.es_direccion, $3.es_direccion);
    } |
    TOK_NOT exp {
        if ($2.tipo == ENTERO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un entero, pero se usa en una negacion logica.\n", row, col, $2.lexema);
            return PARAR_COMPILADOR;
        }

        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        no(yyout, $2.es_direccion, etiqueta);
        etiqueta++;
    } |
    TOK_IDENTIFICADOR {
        if ((local && !TablaSimbolos_existe_local(tabla_simbolos, $1.lexema)) || (!local && !TablaSimbolos_existe_global(tabla_simbolos, $1.lexema))) {
            printf("Error semantico [lin %d, col %d]: El identificador %s no ha sido declarado.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $1.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $1.lexema));
        if (atributos_actuales.categoria == FUNCION) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a una funcion, por lo que no se puede acceder a su valor.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        } else if (atributos_actuales.clase == VECTOR) {
            printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un vector, por lo que no se puede acceder a su valor.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }

        $$.tipo = atributos_actuales.tipo;
        $$.es_direccion = TRUE;

        if (atributos_actuales.categoria == PARAMETRO) {
            escribirParametro(yyout, atributos_actuales.pos_parametro, num_parametros_actual);
        } else {
            if (local && TablaSimbolos_existe_local_estricto(tabla_simbolos, $1.lexema)) {
                escribirVariableLocal(yyout, atributos_actuales.pos_variable_local);
            } else {
                escribir_operando(yyout, $1.lexema, TRUE);
            }
        }

        if (en_explist) {
            operandoEnPilaAArgumento(yyout, TRUE);
            $$.es_direccion = FALSE;
        }
    } |
    constante { 
        $$.tipo = $1.tipo;
        $$.es_direccion = $1.es_direccion; 
    } |
    TOK_PARENTESISIZQUIERDO exp TOK_PARENTESISDERECHO {
        $$.tipo = $2.tipo;
        $$.es_direccion = $2.es_direccion; 
    } |
    TOK_PARENTESISIZQUIERDO comparacion TOK_PARENTESISDERECHO {
        $$.tipo = $2.tipo;
        $$.es_direccion = $2.es_direccion; 
    } |
    elemento_vector { 
        $$.tipo = $1.tipo;
        $$.es_direccion = $1.es_direccion; 
        if (en_explist) operandoEnPilaAArgumento(yyout, TRUE);
    } |
    idf_llamada_funcion TOK_PARENTESISIZQUIERDO lista_expresiones TOK_PARENTESISDERECHO {
        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $1.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $1.lexema));
        if (num_parametros_llamada_actual != atributos_actuales.num_parametros) {
            printf("Error semantico [lin %d, col %d]: En la llamada a la funcion %s se esperaban %d argumentos, pero se obtuvieron %d.\n", row, col, $1.lexema, atributos_actuales.num_parametros, num_parametros_llamada_actual);
            return PARAR_COMPILADOR;
        }

        en_explist = FALSE;
        $$.es_direccion = FALSE;
        $$.tipo = atributos_actuales.tipo;

        llamarFuncion(yyout, $1.lexema, atributos_actuales.num_parametros);
    };

idf_llamada_funcion:
    TOK_IDENTIFICADOR {
        if ((local && !TablaSimbolos_existe_local(tabla_simbolos, $1.lexema)) || (!local && !TablaSimbolos_existe_global(tabla_simbolos, $1.lexema))) {
            printf("Error semantico [lin %d, col %d]: El identificador %s no ha sido declarado.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        atributos_actuales = *(local ? TablaSimbolos_uso_local(tabla_simbolos, $1.lexema) : TablaSimbolos_uso_global(tabla_simbolos, $1.lexema));
        if (atributos_actuales.categoria != FUNCION) {
            if (atributos_actuales.clase == ESCALAR) {
                printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un escalar, por lo que no es invocable.\n", row, col, $1.lexema);
                return PARAR_COMPILADOR;
            } else {
                printf("Error semantico [lin %d, col %d]: El identificador %s corresponde a un vector, por lo que no es invocable.\n", row, col, $1.lexema);
                return PARAR_COMPILADOR;
            }
        }

        if (en_explist == TRUE) {
            printf("Error semantico [lin %d, col %d]: Se estan anidando las llamadas a funcion.\n", row, col);
            return PARAR_COMPILADOR;
        }

        num_parametros_llamada_actual = 0;
        en_explist = TRUE;
        strcpy($$.lexema, $1.lexema);
    };

lista_expresiones:
    exp resto_lista_expresiones {
        num_parametros_llamada_actual++;
    } |
    /* lambda */;

resto_lista_expresiones:
    TOK_COMA exp resto_lista_expresiones {
        num_parametros_llamada_actual++;
    } |
    /* lambda */;

comparacion:
    exp TOK_IGUAL exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        igual(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    } |
    exp TOK_DISTINTO exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        distinto(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    } |
    exp TOK_MENORIGUAL exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        menor_igual(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    } |
    exp TOK_MAYORIGUAL exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        mayor_igual(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    } |
    exp TOK_MENOR exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        menor(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    } |
    exp TOK_MAYOR exp { 
        if ($1.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        if ($3.tipo == BOOLEANO) {
            printf("Error semantico [lin %d, col %d]: la expresion %s es un booleano, pero se usa en una comparacion.\n", row, col, $3.lexema);
            return PARAR_COMPILADOR;
        }
        
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;

        mayor(yyout, $1.es_direccion, $3.es_direccion, etiqueta);
        etiqueta++;
    }

constante:
    constante_logica { 
        $$.tipo = $1.tipo;
        $$.es_direccion = $1.es_direccion;
    } |
    constante_entera { 
        $$.tipo = $1.tipo;
        $$.es_direccion = $1.es_direccion;
    };

constante_logica:
    TOK_TRUE { 
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;
        escribir_operando(yyout, "1", false);
    } |
    TOK_FALSE { 
        $$.tipo = BOOLEANO;
        $$.es_direccion = FALSE;
        escribir_operando(yyout, "0", false);
    };

constante_entera:
    TOK_CONSTANTE_ENTERA {
        $$.tipo = ENTERO;
        $$.es_direccion = FALSE;
        sprintf(atributos_actuales.lexema, "%d", $1.valor_entero);
        escribir_operando(yyout, atributos_actuales.lexema, false);
    };

identificador:
    TOK_IDENTIFICADOR {
        strcpy(atributos_actuales.lexema, $1.lexema);
        atributos_actuales.categoria = VARIABLE;
        atributos_actuales.clase = clase_actual;
        atributos_actuales.tipo = tipo_actual;
        atributos_actuales.numero_elementos = tam_vector_actual;

        if (local) {
            if (TablaSimbolos_existe_local_estricto(tabla_simbolos, $1.lexema)) {
                printf("Error semantico [lin %d, col %d]: Identificador %s duplicado.\n", row, col, $1.lexema);
                return PARAR_COMPILADOR;
            } else {
                atributos_actuales.pos_variable_local = pos_variable_local_actual;
                TablaSimbolos_declarar_local(tabla_simbolos, $1.lexema, &atributos_actuales);
                num_variables_locales_actual++;
                pos_variable_local_actual++;
            }
        } else {
            if (TablaSimbolos_existe_global(tabla_simbolos, $1.lexema)) {
                printf("Error semantico [lin %d, col %d]: Identificador %s duplicado.\n", row, col, $1.lexema);
                return PARAR_COMPILADOR;
            } else {
                TablaSimbolos_declarar_global(tabla_simbolos, $1.lexema, &atributos_actuales);
            }
        }
    };

idpf:
    TOK_IDENTIFICADOR {
        strcpy(atributos_actuales.lexema, $1.lexema);
        if (TablaSimbolos_existe_local_estricto(tabla_simbolos, $1.lexema)) {
            printf("Error semantico [lin %d, col %d]: Identificador %s duplicado en la declaracion de la funcion.\n", row, col, $1.lexema);
            return PARAR_COMPILADOR;
        }
        atributos_actuales.categoria = PARAMETRO;
        atributos_actuales.clase = VARIABLE;
        atributos_actuales.tipo = tipo_actual;
        atributos_actuales.pos_parametro = pos_parametro_actual;
        TablaSimbolos_declarar_local(tabla_simbolos, $1.lexema, &atributos_actuales);
        pos_parametro_actual++;
        num_parametros_actual++;
    };

%%

int main(int argc, char **argv) {
    int status;

    if (argc != 3) {
        printf("Error: Numero incorrecto de argumentos.\n");
        return -1;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        printf("Error: No se ha podido abrir el fichero %s.\n", argv[1]);
        return -1;
    }

    yyout = fopen(argv[2], "w");
    if (yyout == NULL) {
        printf("Error: No se ha podido abrir el fichero %s.\n", argv[2]);
        fclose(yyin);
        return -1;
    }

    tabla_simbolos = TablaSimbolos_create();
    if (tabla_simbolos == NULL) {
        printf("Error: No se ha podido crear la tabla de simbolos.\n");
        fclose(yyin);
        fclose(yyout);
        return -1;
    }

    local = false;

    status = yyparse();

    TablaSimbolos_free(tabla_simbolos);
    fclose(yyin);
    fclose(yyout);

    return status;
}

int yyerror(char *s) {
    if (codigo_tok != TOK_ERROR) {
        printf("Error sintactico [lin %d, col %d]\n", row, col-yyleng);
    }
    return 0;
}