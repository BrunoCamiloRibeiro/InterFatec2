import os
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

def main():
    out_dir = os.path.abspath('docs/screenshots')
    os.makedirs(out_dir, exist_ok=True)

    options = Options()
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    driver = webdriver.Chrome(options=options)

    screens = [
        ('01_login_motorista_desktop.png', 'http://localhost:8080/#/login', 1280, 800, False),
        ('02_login_paciente_desktop.png', 'http://localhost:8080/#/login-paciente', 1280, 800, False),
        ('03_login_mobile.png', 'http://localhost:8080/#/login', 390, 844, True),
        ('04_login_paciente_mobile.png', 'http://localhost:8080/#/login-paciente', 390, 844, True),
        ('05_admin_gerenciador_viagens_desktop.png', 'http://localhost:8080/#/gerenciador-viagens', 1280, 800, False),
        ('06_admin_gerenciador_viagens_mobile.png', 'http://localhost:8080/#/gerenciador-viagens', 390, 844, True),
        ('07_admin_gestao_pessoas_desktop.png', 'http://localhost:8080/#/lista-pessoas', 1280, 800, False),
        ('08_admin_gestao_pessoas_mobile.png', 'http://localhost:8080/#/lista-pessoas', 390, 844, True),
        ('09_motorista_inicio_viagem_desktop.png', 'http://localhost:8080/#/inicio-viagem', 1280, 800, False),
        ('10_motorista_inicio_viagem_mobile.png', 'http://localhost:8080/#/inicio-viagem', 390, 844, True),
        ('11_motorista_lista_passageiros_desktop.png', 'http://localhost:8080/#/motorista-viagem', 1280, 800, False),
        ('12_motorista_lista_passageiros_mobile.png', 'http://localhost:8080/#/motorista-viagem', 390, 844, True),
        ('13_motorista_confirmacao_finalizacao.png', 'http://localhost:8080/#/motorista-confirmacao', 1280, 800, False),
        ('14_motorista_formulario_encerramento.png', 'http://localhost:8080/#/motorista-encerramento', 1280, 800, False),
        ('15_paciente_painel_desktop.png', 'http://localhost:8080/#/paciente-painel', 1280, 800, False),
        ('16_paciente_painel_mobile.png', 'http://localhost:8080/#/paciente-painel', 390, 844, True),
    ]

    for filename, url, width, height, is_mobile in screens:
        driver.execute_cdp_cmd('Emulation.setDeviceMetricsOverride', {
            'width': width,
            'height': height,
            'deviceScaleFactor': 1,
            'mobile': is_mobile
        })
        driver.get(url)
        time.sleep(3.5)
        filepath = os.path.join(out_dir, filename)
        driver.save_screenshot(filepath)
        size_kb = os.path.getsize(filepath) / 1024
        print(f"Captured {filename}: {width}x{height} ({size_kb:.1f} KB)")

    driver.quit()
    print("All screenshots successfully captured!")

if __name__ == '__main__':
    main()
