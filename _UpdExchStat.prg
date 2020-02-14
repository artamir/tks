PARAMETER Mode, Node, Num, CntUpperB, StatId, PushAll

SET DELETED OFF
SET MULTILOCKS ON
SET EXCLUSIVE OFF

USE 1supdts AGAIN ALIAS updts IN 0 SHARED

&& оптимистичная блокировка таблицы
CURSORSETPROP('buffering', 5) 

IF Mode = 0 
&& выборка элементов для выгрузки

    GO TOP

    m.Cnt = 0

&& статус до выгрузки изменений    
    LOCATE FOR dbsign = Node AND dwnldid = '     0'
    DO WHILE FOUND()

&& номер сообщения обмена
        REPLACE dwnldid WITH Num 

        m.Cnt = m.Cnt + 1

        IF m.Cnt = CntUpperB

&& контроль количества объектов в выгрузке
            EXIT
        ENDIF

        CONTINUE

    ENDDO

ELSE 
&& выборка элементов для удаления

&& таблица подтвержденных в базе-приемнике объектов
    USE 1sexch ALIAS exch IN 0 SHARED

    SELECT exch
    DO WHILE NOT EOF() 

&& подтвержденный в приемнике объект        
        SELECT updts
        
        LOCATE FOR dbsign = Node AND objid = exch.f1
        IF FOUND()

&& номер подтвержденного сообщения обмена            
            IF Val(dwnldid) <= Val(Num) AND (Val(dwnldid) > 0 OR PushAll = 1) 

&& исключение из обмена 
                REPLACE dwnldid WITH StatId
            ENDIF

        ENDIF

        SELECT exch

        SKIP

    ENDDO

ENDIF

&& попытка условной записи изменений
SELECT updts

BEGIN TRANSACTION
lSuccess = TABLEUPDATE(.T.,.F.) 

IF lSuccess = .F.

&& откат транзакции
    ROLLBACK 
    
    AERROR(aErrors)

    DO CASE
    CASE aErrors[1,1] = 1585 
&& конфликт по записи строк

&& блокировка таблицы на запись        
        SET REPROCESS TO 5 SECONDS
        IF FLOCK() 

            nNextModif = getnextmodified(0)
            DO WHILE nNextModif <> 0

&& отмена изменений для каждой измененной строки
                GO nNextModif
                TABLEREVERT(.F.) 
                nNextModif = getnextmodified(nNextModif)

            ENDDO

&& попытка безусловной записи...
            BEGIN TRANSACTION
            TABLEUPDATE(.T.,.T.) 
            END TRANSACTION

            USE

        ELSE
&& не удалось заблокировать таблицу
            RETURN .F. 
        ENDIF

    OTHERWISE
&& непонятная ошибка записи изменений
        RETURN .F. 
    ENDCASE

ELSE
&& успешная запись всех изменений
    END TRANSACTION 
ENDIF

&& изменения (частично) приняты
RETURN .T. 