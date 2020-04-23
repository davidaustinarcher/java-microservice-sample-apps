import os
import pymongo
from bson import json_util

from flask import Flask, jsonify, request

def enabled_in_env(varname):
    val = os.environ.get(varname)
    return val and str(val).lower() not in ('0','false','off','no')

DEBUG = enabled_in_env('FLASK_DEBUG')
print('DEBUG =', DEBUG)

if DEBUG:
    dbc = pymongo.MongoClient('mongodb://host.docker.internal:27017/')
else:
    dbc = pymongo.MongoClient('mongodb://bookstore-mongodb:27017/')

if 'db' not in dbc.list_database_names():
    db = dbc.db
    c = db.reviews
    c.insert_many([
        {'title': 'Dune',
         'user': 'Alice',
         'score': 5.0,
         'comments': 'Dune is the best!'
        },
        {'title': 'Dune',
         'user': 'Bob',
         'score': 4.0,
         'comments': 'One of my favorites'
        },
        {'title': 'Dune',
         'user': 'Charlie',
         'score': 1.0,
         'comments': 'Savage and cruel'
        },
    ])

app = Flask(__name__)

@app.route('/')
def hello_world():
    return jsonify({'message': 'Flask, baby!'})

@app.route('/ping')
def ping():
    return ''

@app.route('/reviews')
def get_reviews():
    matches = dbc.db.reviews.find(request.args.to_dict())
    #matches = dbc.db.reviews.find(request.args.to_dict(), projection=['title','user','score','comments'])

    return app.response_class(
            response=json_util.dumps(list(matches)),
            status=200,
            mimetype='application/json'
    )

@app.route('/reviews', methods=['POST'])
def store_review():
    rec = dbc.db.reviews.insert_one(request.json)
    return app.response_class(
            response=json_util.dumps({
                'success': True,
                'objectid': rec.inserted_id
            }),
            status=200,
            mimetype='application/json'
    )

if __name__ == '__main__':
    app.run(debug=DEBUG, host='0.0.0.0')
