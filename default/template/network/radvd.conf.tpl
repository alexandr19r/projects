# /etc/radvd.conf
# [radvd.conf] - Конфигурационный файл демона объявлений маршрутизатора (Router Advertisement Daemon)
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

interface ${DHCP_INTERFACE} {
    AdvSendAdvert on;
    
    # 1. Говорим, что САМ этот сервер НЕ является шлюзом по умолчанию
    # Эту строку можно опустить (on по умолчанию)
    # AdvDefaultRouter off; 
    # КРИТИЧНО: Эти флаги перенаправляют клиента к вашему DHCPv6
    AdvManagedFlag on;      # Иди к DHCP за IPv6 адресом (M-флаг)
    AdvOtherConfigFlag on;  # Иди к DHCP за DNS и доменом (O-флаг)

    MinRtrAdvInterval 3;
    MaxRtrAdvInterval 10;

    prefix ${YOUR_NETWORK_IPV6} {
        AdvOnLink on;
        
        # Если вы хотите, чтобы адреса выдавал ТОЛЬКО DHCP, ставьте off.
        # Если оставить on, у клиента будет ДВА IPv6 (один от SLAAC, второй от DHCP).
        AdvAutonomous off; 
        
        # Сообщаем клиентам, что МЫ (этот сервер) — их выход в мир
        AdvRouterAddr on; 
    };
    
    # 2. AdvDefaultRouter off; и AdvRouterAddr off; 
    # Анонсируем маршрут через ДРУГОЙ шлюз (если поддерживается клиентами)
    # ВНИМАНИЕ: Обычно в IPv6 шлюз выбирается автоматически по анонсу от САМОГО шлюза.
    # Если второй роутер тоже умеет RA, лучше запустить radvd там.
};
