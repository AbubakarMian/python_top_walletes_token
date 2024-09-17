from flask import Flask, request, jsonify
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support import expected_conditions as EC
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

def get_data_from_page(url):
    logging.debug('Starting get_data_from_page function.')

    options = Options()
    options.headless = True
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

    try:
        driver.get(url)
        logging.debug(f'Opened URL: {url}')

        # Use an explicit wait for the table element to be loaded
        wait = WebDriverWait(driver, 20)  # Extend the wait time if necessary
        table_xpath = '//*[@id="root"]/div/main/div/div/div[2]/div[1]/div[2]/div/div[1]/div[2]/div/div/div/div/table'
        table = wait.until(EC.presence_of_element_located((By.XPATH, table_xpath)))
        logging.debug('Table found.')

        # Ensure rows are present
        rows = table.find_elements(By.XPATH, './/tr')
        logging.debug(f'Found {len(rows)} rows.')

        data = []
        for i, row in enumerate(rows):
            tds = row.find_elements(By.XPATH, './/td')
            logging.debug(f'Row {i} - Number of <td> elements: {len(tds)}')

            if len(tds) >= 1:
                # Extract the div elements from the <td>
                data_list = tds[0].find_elements(By.XPATH, './/div')

                # Check if data_list has at least two elements
                if len(data_list) >= 2:
                    pnl_div = data_list[0].text.strip()
                    address_div = data_list[1].text.strip()
                    data.append({'address': address_div, 'pnl': pnl_div})
                    logging.debug(f'Added data: address={address_div}, pnl={pnl_div}')
                else:
                    logging.warning(f'Row {i} does not have enough <div> elements.')
            else:
                logging.warning(f'Row {i} does not contain enough <td> elements.')

    except Exception as e:
        logging.error(f'Error occurred: {str(e)}')
        raise
    finally:
        driver.quit()
        logging.debug('Driver quit.')

    return data


@app.route('/scrap', methods=['GET'])
def scrap():
    token = request.args.get('token')
    if not token:
        return jsonify({'error': 'Token parameter is required'}), 400

    url = f'https://dexscreener.com/solana/{token}?embed=1&theme=dark&info=1'
    logging.debug(f'Received request for token: {token}')
    
    try:
        data = get_data_from_page(url)
        logging.debug(f'Retrieved data: {data}')
        return jsonify(data)
    except Exception as e:
        logging.error(f'Error in /scrap route: {str(e)}')
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True)
