PARAMETER Mode, Node, Num, CntUpperB, StatId, PushAll

SET DELETED OFF
SET MULTILOCKS ON
SET EXCLUSIVE OFF

USE 1supdts AGAIN ALIAS updts IN 0 SHARED

&& ������������� ���������� �������
CURSORSETPROP('buffering', 5) 

IF Mode = 0 
&& ������� ��������� ��� ��������

    GO TOP

    m.Cnt = 0

&& ������ �� �������� ���������    
    LOCATE FOR dbsign = Node AND dwnldid = '     0'
    DO WHILE FOUND()

&& ����� ��������� ������
        REPLACE dwnldid WITH Num 

        m.Cnt = m.Cnt + 1

        IF m.Cnt = CntUpperB

&& �������� ���������� �������� � ��������
            EXIT
        ENDIF

        CONTINUE

    ENDDO

ELSE 
&& ������� ��������� ��� ��������

&& ������� �������������� � ����-��������� ��������
    USE 1sexch ALIAS exch IN 0 SHARED

    SELECT exch
    DO WHILE NOT EOF() 

&& �������������� � ��������� ������        
        SELECT updts
        
        LOCATE FOR dbsign = Node AND objid = exch.f1
        IF FOUND()

&& ����� ��������������� ��������� ������            
            IF Val(dwnldid) <= Val(Num) AND (Val(dwnldid) > 0 OR PushAll = 1) 

&& ���������� �� ������ 
                REPLACE dwnldid WITH StatId
            ENDIF

        ENDIF

        SELECT exch

        SKIP

    ENDDO

ENDIF

&& ������� �������� ������ ���������
SELECT updts

BEGIN TRANSACTION
lSuccess = TABLEUPDATE(.T.,.F.) 

IF lSuccess = .F.

&& ����� ����������
    ROLLBACK 
    
    AERROR(aErrors)

    DO CASE
    CASE aErrors[1,1] = 1585 
&& �������� �� ������ �����

&& ���������� ������� �� ������        
        SET REPROCESS TO 5 SECONDS
        IF FLOCK() 

            nNextModif = getnextmodified(0)
            DO WHILE nNextModif <> 0

&& ������ ��������� ��� ������ ���������� ������
                GO nNextModif
                TABLEREVERT(.F.) 
                nNextModif = getnextmodified(nNextModif)

            ENDDO

&& ������� ����������� ������...
            BEGIN TRANSACTION
            TABLEUPDATE(.T.,.T.) 
            END TRANSACTION

            USE

        ELSE
&& �� ������� ������������� �������
            RETURN .F. 
        ENDIF

    OTHERWISE
&& ���������� ������ ������ ���������
        RETURN .F. 
    ENDCASE

ELSE
&& �������� ������ ���� ���������
    END TRANSACTION 
ENDIF

&& ��������� (��������) �������
RETURN .T. 